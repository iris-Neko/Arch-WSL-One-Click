# Arch Linux WSL 自动化配置工具 v4.5

> 一键配置 Arch Linux WSL 环境 • 生产级 • 配置驱动

## 🚀 快速开始

### 最简单的方式

```bash
# 克隆仓库
git clone <repo-url>
cd Arch-WSL-One-Click

# 运行一键安装（自动配置）
sudo bash bootstrap.sh
```

### 中国用户优化（推荐）

```bash
# 使用中国优化配置
cp setup-china.yaml setup.yaml

# 运行安装
sudo bash bootstrap.sh
```

---

## 📋 功能特性

### 🎯 核心功能

- ✅ **系统更新** - 自动更新 Arch Linux 系统
- ✅ **包管理** - 安装基础包和可选包
- ✅ **用户配置** - 创建用户并配置权限
- ✅ **Shell 美化** - Oh My Zsh + 插件
- ✅ **开发工具** - Yay (AUR)、Miniconda
- ✅ **GitHub 集成** - GitHub CLI 配置

### 🛡️ 生产级特性

- 📊 **结果摘要** - 表格展示所有任务状态和耗时
- 🔒 **Pacman 锁清理** - 自动检测和清理 db.lck
- 🌐 **网络预检** - 执行前检查网络连通性
- 🔄 **重试机制** - 网络操作自动重试
- 🧹 **资源清理** - Ctrl+C 自动清理临时文件
- 🔐 **敏感信息脱敏** - 日志中屏蔽密码
- 📋 **日志持久化** - `/var/log/arch_wsl_setup.log`
- ⚡ **并发优化** - 插件并发安装，提速 50%
- 🗂️ **现代化路径** - pathlib 处理，WSL 友好

### 🇨🇳 中国用户友好

- 🚀 **镜像源配置** - 清华/科大/阿里云等镜像
- 🌍 **代理支持** - HTTP/SOCKS5 代理
- ⚡ **下载加速** - 国内 CDN 加速

---

## ⚙️ 配置文件

### 1. 通用配置

```bash
# 复制示例配置
cp setup.yaml.example setup.yaml

# 编辑配置
nano setup.yaml
```

### 2. 中国优化配置（推荐）

```bash
# 使用预配置的中国优化
cp setup-china.yaml setup.yaml
```

### 3. 主要配置项

```yaml
# 启用中国镜像源（中国用户推荐）
ENABLE_CHINA_MIRRORS: true

# 代理配置（可选）
PROXY: "http://127.0.0.1:7890"

# 包列表
PKG_BASE:
  - base-devel
  - git
  - zsh
  # ...更多包

# Zsh 插件
ZSH_PLUGINS:
  zsh-autosuggestions: https://github.com/zsh-users/zsh-autosuggestions
  zsh-syntax-highlighting: https://github.com/zsh-users/zsh-syntax-highlighting.git
```

---

## 📊 使用流程

### 标准流程

```
1. bootstrap.sh 初始化
   ├─ 初始化 Pacman
   ├─ 安装 Python
   ├─ 安装 PyYAML
   └─ 检查配置文件
   
2. arch_wsl_setup.py 主程序
   ├─ 加载 setup.yaml 配置
   ├─ 显示功能菜单
   ├─ 收集用户信息
   └─ 执行安装任务
   
3. 执行结果摘要
   └─ 表格展示所有任务状态
```

### 执行示例

```
================================================================================
  📊 执行结果摘要
================================================================================
任务名称                         状态        耗时        备注
--------------------------------------------------------------------------------
配置镜像源                       ✓ 成功      1.2s       -
系统更新                         ✓ 成功      45.2s      -
安装基础包                       ✓ 成功      120.3s     -
创建用户                         ○ 跳过      0.1s       用户已存在
配置 WSL                         ✓ 成功      0.2s       -
安装 Oh My Zsh                   ✓ 成功      15.8s      -
安装 Zsh 插件                    ✓ 成功      8.3s       -
配置 .zshrc                      ✓ 成功      0.3s       -
安装 Yay                         ✓ 成功      95.6s      -
安装 Miniconda                   ○ 跳过      0.1s       已安装
配置 GitHub                      ✓ 成功      30.2s      -
--------------------------------------------------------------------------------
总计: 11 个任务 | 成功: 9 | 跳过: 2 | 失败: 0 | 总耗时: 317.3s
================================================================================
```

---

## 🎯 高级用法

### 生成配置文件

```bash
sudo python3 arch_wsl_setup.py --gen-config
```

### 自定义镜像源

```yaml
# setup.yaml
ENABLE_CHINA_MIRRORS: true
CHINA_MIRRORS:
  - https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
  - https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
  # 添加更多镜像...
```

### 配置代理

```yaml
# setup.yaml
PROXY: "http://127.0.0.1:7890"
```

### 自定义包列表

```yaml
# setup.yaml
PKG_BASE:
  - base-devel
  - git
  - neovim  # 替换 vim
  - fish    # 额外添加

PKG_OPT:
  - btop    # 替换 htop
  - lsd     # 替换 exa
```

---

## 🔧 故障排查

### Pacman 锁文件错误

**自动处理**: 新版本会自动检测和清理陈旧的锁文件

```
⚠ 检测到 pacman 锁文件
  ✓ 已自动清理陈旧的锁文件
```

### 网络连接失败

**快速失败**: 执行前检查网络

```
✗ 网络连接失败，无法更新系统
  提示: 尝试连接 archlinux.org:80 失败
```

**解决方案**:
1. 检查网络连接
2. 配置代理: `PROXY: "http://127.0.0.1:7890"`
3. 启用中国镜像: `ENABLE_CHINA_MIRRORS: true`

### 配置文件不存在

```bash
# 生成配置
sudo python3 arch_wsl_setup.py --gen-config

# 或复制示例
cp setup.yaml.example setup.yaml
```

---

## 📁 文件结构

```
Arch-WSL-One-Click/
├── bootstrap.sh              # 初始化脚本（入口点）
├── arch_wsl_setup.py         # 主程序
├── setup.yaml.example        # 配置模板（通用）
├── setup-china.yaml          # 配置模板（中国优化）
├── requirements.txt          # Python 依赖
├── MIRRORS_GUIDE.md          # 镜像源配置指南
└── README.md                 # 本文档
```

---

## 📚 文档

- **README.md** - 使用说明（本文档）
- **MIRRORS_GUIDE.md** - 镜像源详细配置指南
- **setup.yaml.example** - 完整配置说明

---

## 🌟 特性对比

| 特性 | 普通脚本 | 本工具 |
|------|----------|--------|
| **配置方式** | 硬编码 | ✅ YAML 外部配置 |
| **错误处理** | 遇错即停 | ✅ 重试 + 降级 |
| **结果展示** | 日志流 | ✅ 表格摘要 |
| **资源清理** | 手动 | ✅ 自动清理 |
| **日志** | 控制台 | ✅ 控制台 + 文件 |
| **并发** | 串行 | ✅ 并发优化 |
| **镜像源** | 无 | ✅ 自动配置 |
| **代理** | 无 | ✅ 全局代理 |
| **安全** | 密码明文 | ✅ 自动脱敏 |

---

## 💡 最佳实践

### 中国用户

1. 使用 `setup-china.yaml` 配置
2. 启用镜像源加速
3. 根据需要配置代理
4. 选择地理位置最近的镜像

### 国际用户

1. 使用 `setup.yaml.example` 配置
2. 保持默认镜像源
3. 根据网络情况调整重试次数

### 企业用户

1. 自定义包列表
2. 配置内部镜像源
3. 启用日志持久化
4. 定期备份配置文件

---

## 🔄 版本历史

### v4.5 (当前)
- ✅ 配置完全外部化（YAML）
- ✅ 中国镜像源支持
- ✅ 结果摘要报告
- ✅ Pacman 锁自动清理
- ✅ 网络预检
- ✅ 敏感信息脱敏
- ✅ 代理支持

### v4.0
- ✅ 日志持久化
- ✅ 重试机制
- ✅ 并发优化
- ✅ 信号处理

---

## 📄 许可证

MIT License

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## ⭐ Star History

如果这个工具对你有帮助，请给个 Star ⭐

---

**一键配置，专注开发！** 🚀

