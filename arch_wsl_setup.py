#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Arch Linux WSL 自动化配置工具 - 高内聚低耦合版本
设计模式：策略模式 + 命令模式 + 装饰器注册
"""

import os
import sys
import subprocess
import getpass
from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Callable
from dataclasses import dataclass, field


# ==========================================
# 配置模块 - 纯数据，零依赖
# ==========================================
class Cfg:
    """配置中心"""
    # 包列表
    PKG_BASE = ["base-devel", "git", "zsh", "nano", "vim", "tmux", "wget", 
                "curl", "unzip", "openssh", "man-db", "net-tools", "fastfetch", "sudo"]
    PKG_OPT = ["htop", "neofetch", "tree", "fzf", "ripgrep", "bat", "exa"]
    PKG_GH = ["github-cli"]
    
    # 路径
    WSL_CONF = "/etc/wsl.conf"
    SUDOERS = "/etc/sudoers"
    
    # URL
    OMZ_URL = "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    CONDA_URL = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    YAY_REPO = "https://aur.archlinux.org/yay.git"
    
    ZSH_PLUGINS = {
        "zsh-autosuggestions": "https://github.com/zsh-users/zsh-autosuggestions",
        "zsh-syntax-highlighting": "https://github.com/zsh-users/zsh-syntax-highlighting.git"
    }
    
    # 颜色
    C = {'G': '\033[0;32m', 'B': '\033[0;34m', 'R': '\033[0;31m', 
         'Y': '\033[1;33m', 'C': '\033[0;36m', 'N': '\033[0m'}


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
# 工具函数 - 无状态的纯函数
# ==========================================
def run(cmd: str, user: str = None, check: bool = True) -> subprocess.CompletedProcess:
    """执行命令"""
    if user:
        cmd = f"su - {user} -c '{cmd}'"
    return subprocess.run(cmd, shell=True, check=check, capture_output=True, text=True)

def exists(cmd: str) -> bool:
    """检查命令是否存在"""
    return subprocess.run(f"command -v {cmd}", shell=True, 
                         capture_output=True).returncode == 0

def user_exists(name: str) -> bool:
    """检查用户是否存在"""
    return subprocess.run(f"id {name}", shell=True, 
                         capture_output=True).returncode == 0

def log(msg: str, c: str = 'N'):
    """彩色日志"""
    print(f"{Cfg.C[c]}{msg}{Cfg.C['N']}")

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
    
    @abstractmethod
    def execute(self):
        """执行功能"""
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
@Registry.register('update', order=10)
class UpdateSystem(Feature):
    name = "系统更新"
    
    def execute(self):
        section(self.name)
        log("正在更新系统...", 'G')
        run("pacman -Syyu --noconfirm")
        log("✓ 完成", 'G')


@Registry.register('base', order=11)
class InstallBase(Feature):
    name = "安装基础包"
    
    def execute(self):
        section(self.name)
        log(f"正在安装 {len(Cfg.PKG_BASE)} 个包...", 'G')
        run(f"pacman -S --noconfirm {' '.join(Cfg.PKG_BASE)}")
        log("✓ 完成", 'G')


@Registry.register('optional', order=12)
class InstallOptional(Feature):
    name = "安装可选包"
    
    def execute(self):
        section(self.name)
        log(f"正在安装 {len(Cfg.PKG_OPT)} 个可选包...", 'G')
        run(f"pacman -S --noconfirm {' '.join(Cfg.PKG_OPT)}")
        log("✓ 完成", 'G')


@Registry.register('user', order=20)
class CreateUser(Feature):
    name = "创建用户"
    needs_user = True
    
    def execute(self):
        section(f"{self.name}: {self.ctx.username}")
        if user_exists(self.ctx.username):
            log(f"用户 {self.ctx.username} 已存在，跳过", 'Y')
            return
        
        run(f"useradd -m -G wheel -s {self.ctx.shell} {self.ctx.username}")
        run(f"echo '{self.ctx.username}:{self.ctx.password}' | chpasswd")
        
        # 配置 sudo
        with open(Cfg.SUDOERS, 'r') as f:
            content = f.read()
        if "# %wheel ALL=(ALL:ALL) ALL" in content:
            content = content.replace("# %wheel ALL=(ALL:ALL) ALL", "%wheel ALL=(ALL:ALL) ALL")
        elif "%wheel ALL=(ALL:ALL) ALL" not in content:
            content += "\n%wheel ALL=(ALL:ALL) ALL\n"
        with open(Cfg.SUDOERS, 'w') as f:
            f.write(content)
        
        log("✓ 完成", 'G')


@Registry.register('wsl', order=21)
class ConfigureWSL(Feature):
    name = "配置 WSL"
    needs_user = True
    
    def execute(self):
        section(self.name)
        config = f"[user]\ndefault={self.ctx.username}\n\n[boot]\nsystemd={str(self.ctx.enable_systemd).lower()}\n"
        with open(Cfg.WSL_CONF, 'w') as f:
            f.write(config)
        log(f"✓ 默认用户: {self.ctx.username}, Systemd: {self.ctx.enable_systemd}", 'G')


@Registry.register('omz', order=30)
class InstallOhMyZsh(Feature):
    name = "安装 Oh My Zsh"
    needs_user = True
    
    def execute(self):
        section(self.name)
        if os.path.exists(f"{self.ctx.user_home}/.oh-my-zsh"):
            log("已安装，跳过", 'Y')
            return
        run(f'sh -c "$(curl -fsSL {Cfg.OMZ_URL})" "" --unattended', user=self.ctx.username)
        log("✓ 完成", 'G')


@Registry.register('zsh-plugins', order=31)
class InstallZshPlugins(Feature):
    name = "安装 Zsh 插件"
    needs_user = True
    
    def execute(self):
        section(self.name)
        custom = f"{self.ctx.user_home}/.oh-my-zsh/custom/plugins"
        for name, url in Cfg.ZSH_PLUGINS.items():
            path = f"{custom}/{name}"
            if os.path.exists(path):
                log(f"{name} 已安装", 'Y')
                continue
            run(f"git clone {url} {path}", user=self.ctx.username)
            log(f"✓ {name}", 'G')


@Registry.register('zshrc', order=32)
class ConfigureZshrc(Feature):
    name = "配置 .zshrc"
    needs_user = True
    
    def execute(self):
        section(self.name)
        zshrc = f"{self.ctx.user_home}/.zshrc"
        if not os.path.exists(zshrc):
            log(".zshrc 不存在，跳过", 'Y')
            return
        
        with open(zshrc, 'r') as f:
            content = f.read()
        
        # 配置插件
        content = content.replace('plugins=(git)', 
                                 'plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)')
        
        # 添加配置
        additions = [
            ('export EDITOR=', '\nexport EDITOR=nano\n'),
            ('fastfetch', '\n# System info\nfastfetch\n')
        ]
        for check, add in additions:
            if check not in content:
                content += add
        
        with open(zshrc, 'w') as f:
            f.write(content)
        log("✓ 完成", 'G')


@Registry.register('yay', order=40)
class InstallYay(Feature):
    name = "安装 Yay"
    needs_user = True
    
    def execute(self):
        section(self.name)
        if exists('yay'):
            log("已安装，跳过", 'Y')
            return
        
        build_dir = f"{self.ctx.user_home}/tmp_yay"
        script = f"""
cd {self.ctx.user_home}
rm -rf tmp_yay
mkdir tmp_yay && cd tmp_yay
git clone {Cfg.YAY_REPO}
cd yay
echo '{self.ctx.password}' | sudo -S -v
makepkg -si --noconfirm
cd {self.ctx.user_home}
rm -rf tmp_yay
"""
        run(script, user=self.ctx.username)
        log("✓ 完成", 'G')


@Registry.register('conda', order=41)
class InstallConda(Feature):
    name = "安装 Miniconda"
    needs_user = True
    
    def execute(self):
        section(self.name)
        conda_dir = f"{self.ctx.user_home}/miniconda3"
        if os.path.exists(conda_dir):
            log("已安装，跳过", 'Y')
            return
        
        script = f"""
wget -q {Cfg.CONDA_URL} -O ~/miniconda.sh
bash ~/miniconda.sh -b -p {conda_dir}
rm ~/miniconda.sh
{conda_dir}/bin/conda init zsh
{conda_dir}/bin/conda config --set auto_activate_base false
"""
        run(script, user=self.ctx.username)
        log("✓ 完成", 'G')


@Registry.register('github', order=50)
class ConfigureGitHub(Feature):
    name = "配置 GitHub"
    needs_user = True
    
    def execute(self):
        section(self.name)
        
        # 安装 gh
        if not exists('gh'):
            run(f"pacman -S --noconfirm {' '.join(Cfg.PKG_GH)}")
        
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
        log("\n" + "="*60, 'C')
        log("  Arch Linux WSL 自动化配置工具 v3.0", 'C')
        log("  高内聚 • 低耦合 • 可扩展", 'C')
        log("="*60 + "\n", 'C')
    
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
                feature.execute()
            except Exception as e:
                log(f"✗ 执行失败: {e}", 'R')
                if input("继续? (y/n): ").lower() != 'y':
                    break
    
    def _done(self):
        """完成提示"""
        section("安装完成")
        log("🎉 所有功能已完成！\n", 'G')
        log("重要提示：", 'Y')
        log("  1. 在 PowerShell 中运行: wsl --shutdown", 'C')
        log("  2. 重新启动 WSL", 'C')
        log("\n感谢使用！", 'G')


# ==========================================
# 程序入口
# ==========================================
if __name__ == "__main__":
    try:
        App().run()
    except KeyboardInterrupt:
        log("\n用户取消操作", 'Y')
        sys.exit(0)
    except Exception as e:
        log(f"\n错误: {e}", 'R')
        import traceback
        traceback.print_exc()
        sys.exit(1)
