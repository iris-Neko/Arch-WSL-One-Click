#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Arch Linux WSL 自动化配置工具 - 生产级版本
设计模式：策略模式 + 命令模式 + 装饰器注册
新增特性：重试机制 + 日志持久化 + 并发优化 + 幂等性增强
"""

import os
import sys
import subprocess
import getpass
import re
import logging
import time
import signal
import atexit
import socket
from pathlib import Path
from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Callable, Any
from dataclasses import dataclass, field
from concurrent.futures import ThreadPoolExecutor, as_completed
from functools import wraps
from enum import Enum

# YAML 支持（由 bootstrap.sh 确保已安装）
import yaml


# ==========================================
# 任务状态枚举
# ==========================================
class TaskStatus(Enum):
    """任务执行状态"""
    PENDING = "待执行"
    RUNNING = "执行中"
    SUCCESS = "成功"
    SKIPPED = "跳过"
    FAILED = "失败"


# ==========================================
# 配置模块 - 支持外部化
# ==========================================
class Cfg:
    """配置中心 - 从 YAML 文件加载所有配置"""
    
    # 颜色常量（不可配置）
    C = {'G': '\033[0;32m', 'B': '\033[0;34m', 'R': '\033[0;31m', 
         'Y': '\033[1;33m', 'C': '\033[0;36m', 'N': '\033[0m'}
    
    def __init__(self, config_file: str = "setup.yaml"):
        """初始化配置，从 YAML 文件加载"""
        self.config_file = config_file
        self._load_from_yaml()
    
    def _load_from_yaml(self):
        """从 YAML 文件加载配置"""
        config_path = Path(self.config_file)
        
        # 检查配置文件是否存在
        if not config_path.exists():
            print(f"\n{self.C['R']}✗ 配置文件不存在: {self.config_file}{self.C['N']}")
            print(f"{self.C['Y']}请先创建配置文件：{self.C['N']}")
            print(f"  1. 复制示例配置: cp setup.yaml.example setup.yaml")
            print(f"  2. 或生成新配置: sudo python3 arch_wsl_setup.py --gen-config")
            print(f"\n{self.C['C']}中国用户推荐使用: cp setup-china.yaml setup.yaml{self.C['N']}\n")
            sys.exit(1)
        
        # 加载 YAML 配置
        try:
            with config_path.open('r', encoding='utf-8') as f:
                config_data = yaml.safe_load(f)
                
                if not config_data:
                    print(f"{self.C['R']}✗ 配置文件为空{self.C['N']}")
                    sys.exit(1)
                
                # 将配置应用为类属性
                for key, value in config_data.items():
                    setattr(self, key, value)
                
                print(f"{self.C['G']}✓ 已加载配置文件: {self.config_file}{self.C['N']}")
                
        except yaml.YAMLError as e:
            print(f"{self.C['R']}✗ YAML 解析失败: {e}{self.C['N']}")
            sys.exit(1)
        except Exception as e:
            print(f"{self.C['R']}✗ 配置文件加载失败: {e}{self.C['N']}")
            sys.exit(1)


# ==========================================
# 清理管理器 - 自动清理临时文件
# ==========================================
class CleanupManager:
    """清理管理器：统一管理需要清理的临时文件/目录"""
    
    _instance = None
    _cleanup_items: List[Dict[str, Any]] = []
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def register(self, path: str, item_type: str = "file", user: str = None, description: str = ""):
        """注册需要清理的项目"""
        self._cleanup_items.append({
            "path": path,
            "type": item_type,  # file | dir
            "user": user,
            "description": description
        })
    
    def cleanup(self, force: bool = False):
        """执行清理"""
        if not self._cleanup_items:
            return
        
        logger = get_logger()
        logger.log("\n🧹 正在清理临时文件...", 'INFO', 'Y')
        
        for item in self._cleanup_items:
            path = item["path"]
            if not os.path.exists(path):
                continue
            
            try:
                if item["type"] == "dir":
                    cmd = f"rm -rf {path}"
                else:
                    cmd = f"rm -f {path}"
                
                if item["user"]:
                    subprocess.run(f"su - {item['user']} -c '{cmd}'", 
                                 shell=True, check=False, capture_output=True)
                else:
                    subprocess.run(cmd, shell=True, check=False, capture_output=True)
                
                desc = f" ({item['description']})" if item['description'] else ""
                logger.log(f"  ✓ 已删除: {path}{desc}", 'INFO', 'G')
            except Exception as e:
                logger.log(f"  ⚠ 无法删除 {path}: {e}", 'WARNING', 'Y')
        
        self._cleanup_items.clear()
        logger.log("✓ 清理完成\n", 'INFO', 'G')
    
    def clear(self):
        """清空清理列表（不执行清理）"""
        self._cleanup_items.clear()


def get_cleanup_manager() -> CleanupManager:
    """获取全局清理管理器"""
    return CleanupManager()


# ==========================================
# 任务结果跟踪器
# ==========================================
class TaskTracker:
    """任务结果跟踪器：记录所有任务的执行状态"""
    
    _instance = None
    _tasks: List[Dict[str, Any]] = []
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def record(self, name: str, status: TaskStatus, message: str = "", duration: float = 0):
        """记录任务结果"""
        self._tasks.append({
            "name": name,
            "status": status,
            "message": message,
            "duration": duration
        })
    
    def print_summary(self):
        """打印结果摘要表格"""
        if not self._tasks:
            return
        
        cfg = get_config()
        log("\n" + "="*80, 'B')
        log("  📊 执行结果摘要", 'B')
        log("="*80, 'B')
        
        # 表头
        header = f"{'任务名称':<30} {'状态':<10} {'耗时':<10} {'备注'}"
        log(header, 'C')
        log("-"*80, 'C')
        
        # 统计
        success_count = sum(1 for t in self._tasks if t['status'] == TaskStatus.SUCCESS)
        skipped_count = sum(1 for t in self._tasks if t['status'] == TaskStatus.SKIPPED)
        failed_count = sum(1 for t in self._tasks if t['status'] == TaskStatus.FAILED)
        total_duration = sum(t['duration'] for t in self._tasks)
        
        # 表格内容
        for task in self._tasks:
            status_display = {
                TaskStatus.SUCCESS: f"{cfg.C['G']}✓ {task['status'].value}{cfg.C['N']}",
                TaskStatus.SKIPPED: f"{cfg.C['Y']}○ {task['status'].value}{cfg.C['N']}",
                TaskStatus.FAILED: f"{cfg.C['R']}✗ {task['status'].value}{cfg.C['N']}"
            }
            
            status_str = status_display.get(task['status'], task['status'].value)
            duration_str = f"{task['duration']:.1f}s" if task['duration'] > 0 else "-"
            message_str = task['message'][:30] if task['message'] else "-"
            
            # 直接打印（绕过日志系统以保持格式）
            print(f"{task['name']:<30} {task['status'].value:<10} {duration_str:<10} {message_str}")
        
        log("-"*80, 'C')
        log(f"总计: {len(self._tasks)} 个任务 | "
            f"{cfg.C['G']}成功: {success_count}{cfg.C['N']} | "
            f"{cfg.C['Y']}跳过: {skipped_count}{cfg.C['N']} | "
            f"{cfg.C['R']}失败: {failed_count}{cfg.C['N']} | "
            f"总耗时: {total_duration:.1f}s", 'C')
        log("="*80 + "\n", 'B')


def get_task_tracker() -> TaskTracker:
    """获取全局任务跟踪器"""
    return TaskTracker()


# ==========================================
# 上下文对象 - 数据传递容器
# ==========================================
@dataclass
class Context:
    """上下文：存储所有共享数据"""
    username: str = ""
    password: str = ""
    shell: str = "/bin/zsh"
    enable_systemd: bool = True
    user_home: str = ""
    
    def __post_init__(self):
        if self.username:
            self.user_home = self._get_home()
    
    def _get_home(self) -> str:
        r = subprocess.run(f"eval echo ~{self.username}", shell=True, 
                          capture_output=True, text=True)
        return r.stdout.strip()


# ==========================================
# 日志系统 - 持久化
# ==========================================
class DualLogger:
    """双输出日志系统：同时输出到控制台和文件"""
    
    def __init__(self, log_file: str):
        self.logger = logging.getLogger('ArchWSL')
        self.logger.setLevel(logging.DEBUG)
        
        # 文件处理器
        try:
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
            fh = logging.FileHandler(log_file, mode='a', encoding='utf-8')
            fh.setLevel(logging.DEBUG)
            fh.setFormatter(logging.Formatter(
                '%(asctime)s [%(levelname)s] %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            ))
            self.logger.addHandler(fh)
        except Exception as e:
            print(f"警告：无法创建日志文件 {log_file}: {e}")
    
    def log(self, msg: str, level: str = 'INFO', color: str = 'N'):
        """同时输出到控制台和文件"""
        cfg = get_config()
        # 控制台输出（带颜色）
        print(f"{cfg.C[color]}{msg}{cfg.C['N']}")
        
        # 文件输出（无颜色）
        log_func = getattr(self.logger, level.lower(), self.logger.info)
        log_func(msg)

# 全局实例
_logger = None
_cfg = None

def get_logger() -> DualLogger:
    """获取全局日志实例"""
    global _logger
    if _logger is None:
        cfg = get_config()
        _logger = DualLogger(cfg.LOG_FILE)
    return _logger

def get_config() -> Cfg:
    """获取全局配置实例"""
    global _cfg
    if _cfg is None:
        _cfg = Cfg()
    return _cfg


# ==========================================
# 重试装饰器 - 网络操作容错
# ==========================================
def retry(times: int = None, delay: int = None, 
          exceptions: tuple = (subprocess.CalledProcessError, Exception)):
    """重试装饰器（从配置读取默认值）"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            cfg = get_config()
            _times = times if times is not None else cfg.RETRY_TIMES
            _delay = delay if delay is not None else cfg.RETRY_DELAY
            
            last_exception = None
            for attempt in range(1, _times + 1):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    if attempt < _times:
                        logger = get_logger()
                        logger.log(f"⚠ 第 {attempt} 次尝试失败: {e}", 'WARNING', 'Y')
                        logger.log(f"⏳ {_delay} 秒后重试...", 'INFO', 'Y')
                        time.sleep(_delay)
                    else:
                        logger = get_logger()
                        logger.log(f"✗ 失败 {_times} 次，放弃: {e}", 'ERROR', 'R')
            raise last_exception
        return wrapper
    return decorator


# ==========================================
# 工具函数 - 无状态的纯函数
# ==========================================
def mask_sensitive_info(cmd: str) -> str:
    """脱敏敏感信息（密码等）"""
    # 屏蔽 chpasswd 中的密码
    cmd = re.sub(r"(echo\s+['\"])[^:]+:([^'\"]+)(['\"].*chpasswd)", r"\1***:***\3", cmd)
    # 屏蔽 sudo -S 中的密码
    cmd = re.sub(r"(echo\s+['\"])([^'\"]+)(['\"].*sudo\s+-S)", r"\1***\3", cmd)
    return cmd


def check_network_connectivity(host: str = None, port: int = None, timeout: int = None) -> bool:
    """检查网络连通性"""
    cfg = get_config()
    host = host or cfg.NETWORK_CHECK_HOST
    port = port or cfg.NETWORK_CHECK_PORT
    timeout = timeout or cfg.NETWORK_CHECK_TIMEOUT
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((host, port))
        sock.close()
        return True
    except (socket.timeout, socket.error, OSError):
        return False


def check_and_remove_pacman_lock() -> bool:
    """检查并清理 pacman 锁文件"""
    lock_file = Path("/var/lib/pacman/db.lck")
    
    if not lock_file.exists():
        return True
    
    log("⚠ 检测到 pacman 锁文件", 'Y')
    
    # 尝试读取锁文件中的 PID
    try:
        with open(lock_file, 'r') as f:
            content = f.read().strip()
            if content.isdigit():
                pid = int(content)
                # 检查进程是否存在
                if Path(f"/proc/{pid}").exists():
                    log(f"  锁文件对应的进程 {pid} 仍在运行，无法自动清理", 'R')
                    return False
    except Exception:
        pass
    
    # 删除锁文件
    try:
        lock_file.unlink()
        log("  ✓ 已自动清理陈旧的锁文件", 'G')
        return True
    except Exception as e:
        log(f"  ✗ 无法删除锁文件: {e}", 'R')
        return False


@retry(times=3, delay=2)
def run(cmd: str, user: str = None, check: bool = True, mask_log: bool = True) -> subprocess.CompletedProcess:
    """执行命令（带敏感信息脱敏）"""
    logger = get_logger()
    cfg = get_config()
    
    # 日志记录（脱敏）
    log_cmd = mask_sensitive_info(cmd) if mask_log else cmd
    logger.logger.debug(f"执行命令: {log_cmd}" + (f" (用户: {user})" if user else ""))
    
    # 设置环境变量（代理）
    env = os.environ.copy()
    if cfg.PROXY:
        env['http_proxy'] = cfg.PROXY
        env['https_proxy'] = cfg.PROXY
        env['HTTP_PROXY'] = cfg.PROXY
        env['HTTPS_PROXY'] = cfg.PROXY
    
    # 执行命令
    if user:
        cmd = f"su - {user} -c '{cmd}'"
    
    return subprocess.run(cmd, shell=True, check=check, capture_output=True, text=True, env=env)

def exists(cmd: str) -> bool:
    """检查命令是否存在"""
    return subprocess.run(f"command -v {cmd}", shell=True, 
                         capture_output=True).returncode == 0

def user_exists(name: str) -> bool:
    """检查用户是否存在"""
    return subprocess.run(f"id {name}", shell=True, 
                         capture_output=True).returncode == 0

def log(msg: str, c: str = 'N'):
    """彩色日志 - 使用新的双输出系统"""
    logger = get_logger()
    level = {'R': 'ERROR', 'Y': 'WARNING', 'G': 'INFO', 'B': 'INFO', 'C': 'INFO', 'N': 'INFO'}.get(c, 'INFO')
    logger.log(msg, level, c)

def section(title: str):
    """打印章节"""
    log(f"\n{'='*50}\n  {title}\n{'='*50}", 'B')

def check_root():
    """检查 root 权限"""
    if os.geteuid() != 0:
        log("错误：需要 root 权限！运行: sudo python3 arch_wsl_setup.py", 'R')
        sys.exit(1)


# ==========================================
# 功能基类 - 定义接口
# ==========================================
class Feature(ABC):
    """功能抽象基类"""
    
    def __init__(self, ctx: Context):
        self.ctx = ctx
        self._start_time = 0
    
    def run_with_tracking(self):
        """执行功能并跟踪结果"""
        tracker = get_task_tracker()
        self._start_time = time.time()
        
        try:
            result = self.execute()
            duration = time.time() - self._start_time
            
            # 根据返回值判断状态
            if result == "skipped":
                tracker.record(self.name, TaskStatus.SKIPPED, "", duration)
            else:
                tracker.record(self.name, TaskStatus.SUCCESS, "", duration)
        except Exception as e:
            duration = time.time() - self._start_time
            tracker.record(self.name, TaskStatus.FAILED, str(e)[:50], duration)
            raise
    
    @abstractmethod
    def execute(self):
        """执行功能（返回 'skipped' 表示跳过）"""
        pass
    
    @property
    @abstractmethod
    def name(self) -> str:
        """功能名称"""
        pass
    
    @property
    def needs_user(self) -> bool:
        """是否需要用户信息"""
        return False
    
    @property
    def order(self) -> int:
        """执行顺序（越小越先执行）"""
        return 50


# ==========================================
# 功能注册器 - 自动管理功能
# ==========================================
class Registry:
    """功能注册中心"""
    _features: Dict[str, type] = {}
    
    @classmethod
    def register(cls, key: str, order: int = 50):
        """装饰器：自动注册功能"""
        def wrapper(feature_class):
            feature_class._key = key
            feature_class._order = order
            cls._features[key] = feature_class
            return feature_class
        return wrapper
    
    @classmethod
    def get(cls, key: str) -> type:
        return cls._features.get(key)
    
    @classmethod
    def all(cls) -> Dict[str, type]:
        return cls._features


# ==========================================
# 具体功能实现 - 使用装饰器自动注册
# ==========================================
@Registry.register('mirrors', order=5)
class ConfigureMirrors(Feature):
    name = "配置镜像源"
    
    def execute(self):
        section(self.name)
        cfg = get_config()
        
        if not cfg.ENABLE_CHINA_MIRRORS:
            log("镜像源配置已禁用，跳过", 'Y')
            return "skipped"
        
        mirrorlist_path = Path("/etc/pacman.d/mirrorlist")
        
        # 备份原始 mirrorlist
        backup_path = Path("/etc/pacman.d/mirrorlist.backup")
        if not backup_path.exists() and mirrorlist_path.exists():
            import shutil
            shutil.copy(mirrorlist_path, backup_path)
            log("✓ 已备份原始 mirrorlist", 'G')
        
        # 生成新的 mirrorlist
        log("正在配置中国镜像源...", 'C')
        mirrors_content = "##\n## Arch Linux 中国镜像源\n"
        mirrors_content += "## 由 arch_wsl_setup.py 自动生成\n##\n\n"
        
        for i, mirror in enumerate(cfg.CHINA_MIRRORS, 1):
            mirrors_content += f"## {i}. {mirror.split('/')[2]}\n"
            mirrors_content += f"Server = {mirror}\n\n"
        
        # 写入 mirrorlist
        mirrorlist_path.write_text(mirrors_content)
        
        log(f"✓ 已配置 {len(cfg.CHINA_MIRRORS)} 个中国镜像源", 'G')
        for i, mirror in enumerate(cfg.CHINA_MIRRORS, 1):
            mirror_name = mirror.split('/')[2]
            log(f"  {i}. {mirror_name}", 'C')
        
        log("\n提示: 原始 mirrorlist 已备份到 /etc/pacman.d/mirrorlist.backup", 'Y')


@Registry.register('update', order=10)
class UpdateSystem(Feature):
    name = "系统更新"
    
    def execute(self):
        section(self.name)
        
        # 检查并清理 pacman 锁
        if not check_and_remove_pacman_lock():
            log("✗ pacman 锁文件清理失败，请手动处理", 'R')
            raise Exception("pacman 锁文件被占用")
        
        # 检查网络连通性
        if not check_network_connectivity():
            log("✗ 网络连接失败，无法更新系统", 'R')
            cfg = get_config()
            log(f"  提示: 尝试连接 {cfg.NETWORK_CHECK_HOST}:{cfg.NETWORK_CHECK_PORT} 失败", 'Y')
            raise Exception("网络不可用")
        
        log("正在更新系统...", 'G')
        try:
            run("pacman -Syyu --noconfirm")
            log("✓ 完成", 'G')
        except subprocess.CalledProcessError as e:
            log(f"⚠ 系统更新遇到问题，但将继续: {e}", 'Y')
            # 尝试刷新密钥环
            try:
                log("尝试刷新 pacman 密钥...", 'C')
                run("pacman-key --init")
                run("pacman-key --populate archlinux")
                run("pacman -Syyu --noconfirm")
                log("✓ 完成", 'G')
            except Exception as e2:
                log(f"✗ 无法完成系统更新: {e2}", 'R')
                raise


@Registry.register('base', order=11)
class InstallBase(Feature):
    name = "安装基础包"
    
    def execute(self):
        section(self.name)
        cfg = get_config()
        log(f"正在安装 {len(cfg.PKG_BASE)} 个包...", 'G')
        try:
            run(f"pacman -S --noconfirm {' '.join(cfg.PKG_BASE)}")
            log("✓ 完成", 'G')
        except subprocess.CalledProcessError as e:
            log("⚠ 批量安装失败，尝试逐个安装...", 'Y')
            failed = []
            for pkg in cfg.PKG_BASE:
                try:
                    run(f"pacman -S --noconfirm {pkg}")
                    log(f"  ✓ {pkg}", 'G')
                except Exception:
                    log(f"  ✗ {pkg}", 'R')
                    failed.append(pkg)
            if failed:
                log(f"⚠ 以下包安装失败: {', '.join(failed)}", 'Y')
            else:
                log("✓ 全部完成", 'G')


@Registry.register('optional', order=12)
class InstallOptional(Feature):
    name = "安装可选包"
    
    def execute(self):
        section(self.name)
        cfg = get_config()
        log(f"正在安装 {len(cfg.PKG_OPT)} 个可选包...", 'G')
        try:
            run(f"pacman -S --noconfirm {' '.join(cfg.PKG_OPT)}")
            log("✓ 完成", 'G')
        except subprocess.CalledProcessError as e:
            log("⚠ 批量安装失败，尝试逐个安装...", 'Y')
            failed = []
            for pkg in cfg.PKG_OPT:
                try:
                    run(f"pacman -S --noconfirm {pkg}")
                    log(f"  ✓ {pkg}", 'G')
                except Exception:
                    log(f"  ✗ {pkg}", 'R')
                    failed.append(pkg)
            if failed:
                log(f"⚠ 以下可选包安装失败（不影响主要功能）: {', '.join(failed)}", 'Y')


@Registry.register('user', order=20)
class CreateUser(Feature):
    name = "创建用户"
    needs_user = True
    
    def execute(self):
        section(f"{self.name}: {self.ctx.username}")
        if user_exists(self.ctx.username):
            log(f"用户 {self.ctx.username} 已存在，跳过", 'Y')
            return "skipped"
        
        cfg = get_config()
        run(f"useradd -m -G wheel -s {self.ctx.shell} {self.ctx.username}")
        run(f"echo '{self.ctx.username}:{self.ctx.password}' | chpasswd")
        
        # 配置 sudo (使用 pathlib)
        sudoers_path = Path(cfg.SUDOERS)
        content = sudoers_path.read_text()
        
        if "# %wheel ALL=(ALL:ALL) ALL" in content:
            content = content.replace("# %wheel ALL=(ALL:ALL) ALL", "%wheel ALL=(ALL:ALL) ALL")
        elif "%wheel ALL=(ALL:ALL) ALL" not in content:
            content += "\n%wheel ALL=(ALL:ALL) ALL\n"
        
        sudoers_path.write_text(content)
        log("✓ 完成", 'G')


@Registry.register('wsl', order=21)
class ConfigureWSL(Feature):
    name = "配置 WSL"
    needs_user = True
    
    def execute(self):
        section(self.name)
        cfg = get_config()
        config = f"[user]\ndefault={self.ctx.username}\n\n[boot]\nsystemd={str(self.ctx.enable_systemd).lower()}\n"
        
        # 使用 pathlib
        wsl_conf_path = Path(cfg.WSL_CONF)
        wsl_conf_path.write_text(config)
        
        log(f"✓ 默认用户: {self.ctx.username}, Systemd: {self.ctx.enable_systemd}", 'G')


@Registry.register('omz', order=30)
class InstallOhMyZsh(Feature):
    name = "安装 Oh My Zsh"
    needs_user = True
    
    def execute(self):
        section(self.name)
        
        # 使用 pathlib
        omz_path = Path(self.ctx.user_home) / ".oh-my-zsh"
        if omz_path.exists():
            log("已安装，跳过", 'Y')
            return "skipped"
        
        cfg = get_config()
        
        # 检查网络
        if not check_network_connectivity():
            log("✗ 网络连接失败", 'R')
            raise Exception("网络不可用")
        
        try:
            # 网络操作已自动带重试机制（run 函数的装饰器）
            run(f'sh -c "$(curl -fsSL {cfg.OMZ_URL})" "" --unattended', user=self.ctx.username)
            log("✓ 完成", 'G')
        except Exception as e:
            log(f"✗ 安装失败: {e}", 'R')
            log("提示: 请检查网络连接或手动安装 Oh My Zsh", 'Y')
            raise


@Registry.register('zsh-plugins', order=31)
class InstallZshPlugins(Feature):
    name = "安装 Zsh 插件"
    needs_user = True
    
    def _install_plugin(self, name: str, url: str, custom_path: Path) -> tuple:
        """安装单个插件（线程安全）"""
        # 使用 pathlib
        plugin_path = custom_path / name
        
        if plugin_path.exists():
            return (name, 'skip', f"{name} 已安装")
        
        try:
            # 注册临时路径，如果安装失败则清理
            cleanup_mgr = get_cleanup_manager()
            cleanup_mgr.register(str(plugin_path), "dir", self.ctx.username, f"插件 {name}")
            
            run(f"git clone {url} {plugin_path}", user=self.ctx.username)
            
            # 安装成功，从清理列表移除
            cleanup_mgr._cleanup_items = [
                item for item in cleanup_mgr._cleanup_items 
                if item['path'] != str(plugin_path)
            ]
            
            return (name, 'success', f"✓ {name}")
        except Exception as e:
            return (name, 'error', f"✗ {name}: {e}")
    
    def execute(self):
        section(self.name)
        cfg = get_config()
        
        # 使用 pathlib
        custom_path = Path(self.ctx.user_home) / ".oh-my-zsh" / "custom" / "plugins"
        
        log(f"并发安装 {len(cfg.ZSH_PLUGINS)} 个插件...", 'C')
        
        # 检查网络
        if not check_network_connectivity():
            log("✗ 网络连接失败", 'R')
            raise Exception("网络不可用")
        
        # 并发执行
        with ThreadPoolExecutor(max_workers=len(cfg.ZSH_PLUGINS)) as executor:
            futures = {
                executor.submit(self._install_plugin, name, url, custom_path): name
                for name, url in cfg.ZSH_PLUGINS.items()
            }
            
            for future in as_completed(futures):
                name, status, msg = future.result()
                color = {'skip': 'Y', 'success': 'G', 'error': 'R'}[status]
                log(msg, color)
        
        log("✓ 插件安装完成", 'G')


@Registry.register('zshrc', order=32)
class ConfigureZshrc(Feature):
    name = "配置 .zshrc"
    needs_user = True
    
    def _ensure_line(self, content: str, pattern: str, line: str) -> str:
        """幂等性添加/替换行（类似 Ansible lineinfile）"""
        if re.search(pattern, content, re.MULTILINE):
            # 已存在，替换
            content = re.sub(pattern, line, content, flags=re.MULTILINE)
            log(f"  已更新: {line[:50]}...", 'Y')
        else:
            # 不存在，添加
            content = content.rstrip() + '\n\n' + line + '\n'
            log(f"  已添加: {line[:50]}...", 'G')
        return content
    
    def execute(self):
        section(self.name)
        
        # 使用 pathlib
        zshrc_path = Path(self.ctx.user_home) / ".zshrc"
        
        if not zshrc_path.exists():
            log(".zshrc 不存在，跳过", 'Y')
            return "skipped"
        
        content = zshrc_path.read_text()
        
        # 配置插件（使用正则匹配）
        plugin_pattern = r'^plugins=\([^)]*\)'
        desired_plugins = 'plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)'
        if re.search(plugin_pattern, content, re.MULTILINE):
            old_match = re.search(plugin_pattern, content, re.MULTILINE)
            if old_match and old_match.group(0) != desired_plugins:
                content = re.sub(plugin_pattern, desired_plugins, content, flags=re.MULTILINE)
                log(f"  插件已更新", 'G')
            else:
                log(f"  插件配置已是最新", 'Y')
        else:
            log("  未找到 plugins 配置", 'Y')
        
        # 幂等性添加配置项
        content = self._ensure_line(content, r'^export EDITOR=.*', 'export EDITOR=nano')
        content = self._ensure_line(content, r'^fastfetch\s*$', '# System info\nfastfetch')
        
        zshrc_path.write_text(content)
        log("✓ 完成", 'G')


@Registry.register('yay', order=40)
class InstallYay(Feature):
    name = "安装 Yay"
    needs_user = True
    
    def execute(self):
        section(self.name)
        if exists('yay'):
            log("已安装，跳过", 'Y')
            return "skipped"
        
        cfg = get_config()
        cleanup_mgr = get_cleanup_manager()
        
        # 使用 pathlib
        build_dir = Path(self.ctx.user_home) / "tmp_yay"
        
        # 注册临时目录清理
        cleanup_mgr.register(str(build_dir), "dir", self.ctx.username, "Yay 构建目录")
        
        # 检查网络
        if not check_network_connectivity():
            log("✗ 网络连接失败", 'R')
            raise Exception("网络不可用")
        
        try:
            script = f"""
cd {self.ctx.user_home}
rm -rf tmp_yay
mkdir tmp_yay && cd tmp_yay
git clone {cfg.YAY_REPO}
cd yay
echo '{self.ctx.password}' | sudo -S -v
makepkg -si --noconfirm
cd {self.ctx.user_home}
rm -rf tmp_yay
"""
            run(script, user=self.ctx.username, mask_log=True)
            log("✓ 完成", 'G')
            
            # 成功后从清理列表移除（脚本已自行清理）
            cleanup_mgr._cleanup_items = [
                item for item in cleanup_mgr._cleanup_items 
                if item['path'] != str(build_dir)
            ]
        except Exception as e:
            log(f"✗ 安装失败: {e}", 'R')
            log("提示: 请检查网络连接或 base-devel 是否已安装", 'Y')
            # 异常时，cleanup 会在退出时自动清理
            raise


@Registry.register('conda', order=41)
class InstallConda(Feature):
    name = "安装 Miniconda"
    needs_user = True
    
    def execute(self):
        section(self.name)
        
        # 使用 pathlib
        conda_dir = Path(self.ctx.user_home) / "miniconda3"
        installer = Path(self.ctx.user_home) / "miniconda.sh"
        
        if conda_dir.exists():
            log("已安装，跳过", 'Y')
            return "skipped"
        
        cfg = get_config()
        cleanup_mgr = get_cleanup_manager()
        
        # 注册临时文件清理
        cleanup_mgr.register(str(installer), "file", self.ctx.username, "Miniconda 安装脚本")
        cleanup_mgr.register(str(conda_dir), "dir", self.ctx.username, "Miniconda 目录（半成品）")
        
        # 检查网络
        if not check_network_connectivity():
            log("✗ 网络连接失败", 'R')
            raise Exception("网络不可用")
        
        try:
            script = f"""
wget -q {cfg.CONDA_URL} -O ~/miniconda.sh
bash ~/miniconda.sh -b -p {conda_dir}
rm ~/miniconda.sh
{conda_dir}/bin/conda init zsh
{conda_dir}/bin/conda config --set auto_activate_base false
"""
            run(script, user=self.ctx.username)
            log("✓ 完成", 'G')
            
            # 成功后从清理列表移除
            cleanup_mgr._cleanup_items = [
                item for item in cleanup_mgr._cleanup_items 
                if item['path'] not in [str(installer), str(conda_dir)]
            ]
        except Exception as e:
            log(f"✗ 安装失败: {e}", 'R')
            log("提示: 请检查网络连接或磁盘空间", 'Y')
            # 异常时，cleanup 会在退出时自动清理
            raise


@Registry.register('github', order=50)
class ConfigureGitHub(Feature):
    name = "配置 GitHub"
    needs_user = True
    
    def execute(self):
        section(self.name)
        cfg = get_config()
        
        # 安装 gh
        if not exists('gh'):
            run(f"pacman -S --noconfirm {' '.join(cfg.PKG_GH)}")
        
        # 配置
        log("请按照提示配置 GitHub (SSH + Web browser 认证)", 'C')
        log("提示：Protocol=SSH, Generate key=Yes, Auth=Web browser", 'Y')
        run("gh auth login", user=self.ctx.username, check=False)
        
        # 同步 git 配置
        try:
            name = run("gh api user -q .name", user=self.ctx.username).stdout.strip()
            email = run("gh api user -q .email", user=self.ctx.username).stdout.strip()
            if name:
                run(f"git config --global user.name '{name}'", user=self.ctx.username)
                run(f"git config --global user.email '{email}'", user=self.ctx.username)
                log(f"✓ Git 配置完成 (用户: {name})", 'G')
        except:
            log("无法自动配置 Git 用户信息", 'Y')


# ==========================================
# 主控制器 - 流程编排
# ==========================================
class App:
    """应用主控制器"""
    
    def __init__(self):
        self.ctx = Context()
        self.selected = []
    
    def run(self):
        """主流程"""
        check_root()
        self._banner()
        self.selected = self._menu()
        self._collect_data()
        self._execute()
        self._done()
    
    def _banner(self):
        cfg = get_config()
        log("\n" + "="*60, 'C')
        log("  Arch Linux WSL 自动化配置工具 v4.0 (生产级)", 'C')
        log("  高内聚 • 低耦合 • 可扩展 • 生产级", 'C')
        log("="*60, 'C')
        log(f"  日志文件: {cfg.LOG_FILE}", 'Y')
        log("="*60 + "\n", 'C')
        log("🚀 开始执行", 'G')
    
    def _menu(self) -> List[str]:
        """显示菜单并获取选择"""
        features = Registry.all()
        sorted_features = sorted(features.items(), key=lambda x: x[1]._order)
        
        log("请选择功能（多选用逗号分隔，A=全部）：\n" + "-"*60, 'B')
        for i, (key, cls) in enumerate(sorted_features, 1):
            # 实例化以访问 name 属性
            temp = cls(Context())
            print(f"  [{i}] {temp.name}")
        log("  [A] 全部安装", 'B')
        log("-"*60 + "\n示例: 1,2,4  或  1-5  或  A", 'Y')
        
        while True:
            choice = input("\n选择: ").strip().upper()
            if choice == 'A':
                return list(features.keys())
            
            try:
                selected = []
                for part in choice.replace('，', ',').split(','):
                    part = part.strip()
                    if '-' in part:
                        start, end = map(int, part.split('-'))
                        selected.extend([sorted_features[i-1][0] for i in range(start, end+1)])
                    else:
                        idx = int(part) - 1
                        selected.append(sorted_features[idx][0])
                if selected:
                    return selected
            except:
                pass
            log("输入无效，请重试", 'R')
    
    def _collect_data(self):
        """收集用户数据"""
        # 检查是否需要用户信息
        needs_user = any(Registry.get(key)(self.ctx).needs_user for key in self.selected)
        if not needs_user:
            return
        
        section("数据收集")
        log("请输入所有信息，之后将全自动运行", 'C')
        
        # 用户名
        while True:
            username = input("\n用户名: ").strip()
            if username:
                if user_exists(username):
                    if input(f"用户 {username} 已存在，继续使用? (y/n): ").lower() == 'y':
                        self.ctx.username = username
                        self.ctx.user_home = self.ctx._get_home()
                        break
                else:
                    self.ctx.username = username
                    break
        
        # 密码（仅在创建用户或安装 yay 时需要）
        if 'user' in self.selected or 'yay' in self.selected:
            while True:
                pwd = getpass.getpass("密码: ")
                pwd2 = getpass.getpass("确认密码: ")
                if pwd and pwd == pwd2:
                    self.ctx.password = pwd
                    break
                log("密码不匹配或为空", 'R')
        
        # Shell
        if 'user' in self.selected and not user_exists(self.ctx.username):
            log("\nShell: 1) bash  2) zsh (推荐)", 'B')
            shell = input("选择 [默认 2]: ").strip() or "2"
            self.ctx.shell = "/bin/zsh" if shell == "2" else "/bin/bash"
        
        # Systemd
        if 'wsl' in self.selected:
            systemd = input("\n启用 Systemd? (Y/n): ").lower() or 'y'
            self.ctx.enable_systemd = (systemd == 'y')
        
        # 更新 home 目录
        if self.ctx.username and not self.ctx.user_home:
            self.ctx.user_home = self.ctx._get_home()
        
        log("\n✓ 数据收集完成！", 'G')
        input("按 Enter 开始安装...")
    
    def _execute(self):
        """执行选中的功能"""
        section("执行安装")
        
        # 按 order 排序执行
        features = [(key, Registry.get(key)) for key in self.selected]
        features.sort(key=lambda x: x[1]._order)
        
        for key, feature_class in features:
            try:
                feature = feature_class(self.ctx)
                feature.run_with_tracking()  # 使用跟踪执行
            except Exception as e:
                log(f"✗ 执行失败: {e}", 'R')
                if input("继续? (y/n): ").lower() != 'y':
                    break
    
    def _done(self):
        """完成提示"""
        cfg = get_config()
        
        # 显示结果摘要
        tracker = get_task_tracker()
        tracker.print_summary()
        
        section("安装完成")
        log("🎉 所有功能已完成！\n", 'G')
        log("重要提示：", 'Y')
        log("  1. 在 PowerShell 中运行: wsl --shutdown", 'C')
        log("  2. 重新启动 WSL", 'C')
        log(f"\n📋 完整日志已保存到: {cfg.LOG_FILE}", 'Y')
        log("感谢使用！", 'G')
        
        # 清空清理列表（正常完成，不需要清理）
        cleanup_mgr = get_cleanup_manager()
        cleanup_mgr.clear()


# ==========================================
# 信号处理与清理钩子
# ==========================================
def signal_handler(signum, frame):
    """信号处理器：捕获中断信号并清理"""
    log("\n\n⚠ 接收到中断信号 (Ctrl+C)", 'Y')
    cleanup_mgr = get_cleanup_manager()
    cleanup_mgr.cleanup()
    log("程序已退出", 'Y')
    sys.exit(130)  # 128 + SIGINT(2)

def cleanup_on_exit():
    """退出时清理钩子"""
    cleanup_mgr = get_cleanup_manager()
    if cleanup_mgr._cleanup_items:
        cleanup_mgr.cleanup()


# ==========================================
# 程序入口
# ==========================================
if __name__ == "__main__":
    # 注册信号处理
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # 注册退出清理钩子
    atexit.register(cleanup_on_exit)
    
    try:
        # 检查是否要生成配置模板
        if len(sys.argv) > 1 and sys.argv[1] == '--gen-config':
            print("\n正在生成配置文件...\n")
            
            # 检查示例文件是否存在
            example_file = Path("setup.yaml.example")
            if not example_file.exists():
                print("✗ 找不到 setup.yaml.example 模板文件")
                sys.exit(1)
            
            # 复制示例文件
            import shutil
            shutil.copy(example_file, "setup.yaml")
            print("✓ 已生成配置文件: setup.yaml")
            print("\n提示:")
            print("  - 通用配置: setup.yaml (已生成)")
            print("  - 中国优化: setup-china.yaml")
            print("\n请编辑 setup.yaml 后运行: sudo python3 arch_wsl_setup.py\n")
            sys.exit(0)
        
        App().run()
    except KeyboardInterrupt:
        log("\n用户取消操作", 'Y')
        # cleanup 会由 atexit 自动调用
        sys.exit(0)
    except Exception as e:
        log(f"\n错误: {e}", 'R')
        import traceback
        traceback.print_exc()
        # cleanup 会由 atexit 自动调用
        sys.exit(1)
