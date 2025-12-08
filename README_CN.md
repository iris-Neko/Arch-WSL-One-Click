# 🚀 Arch WSL 一键全自动配置 (Arch WSL Bootstrap)

> **从零到完美：** 几分钟内将全新的 Windows 环境打造为顶级的 Arch Linux 开发工作站。

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-Distro-blue?logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![WSL 2](https://img.shields.io/badge/Platform-WSL2-orange?logo=windows&logoColor=white)](https://docs.microsoft.com/en-us/windows/wsl/)
[![PowerShell](https://img.shields.io/badge/Script-PowerShell-5391FE?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![English](https://img.shields.io/badge/Docs-English-blue.svg)](./README.md)
![终端预览](screenshot.png)

## 📖 项目介绍

**拒绝重复造轮子，别再浪费时间手动配置 Linux 了。**

本项目提供了一套完整的 **基础设施即代码 (IaC)** 解决方案，专为 Windows Subsystem for Linux (WSL) 设计。它实现了全生命周期的自动化管理：

1.  **Windows 端自动化：** 自动开启 WSL 功能、更新内核、下载并安装 Arch Linux (ArchWSL)。
2.  **Linux 端自动化：** 自动配置用户、Sudo 权限、Pacman 源、AUR (yay)、Zsh、插件体系以及 Conda 环境。

**适用人群：** 希望拥有一个可复现、甚至“用完即丢”的纯净 Arch 开发环境的极客与开发者。

---

## ✨ 核心特性

### 🖥️ Windows 端自动化 (`.ps1`)
* ✅ **自动开启 WSL 2**：智能检测并开启 `Microsoft-Windows-Subsystem-Linux` 和 `VirtualMachinePlatform`。
* ✅ **自动部署 Arch**：自动拉取最新的 [Yuk7/ArchWSL](https://github.com/yuk7/ArchWSL) 发行版。
* ✅ **一键绕过限制**：通过 `.bat` 辅助脚本，自动提权并绕过 PowerShell 执行策略限制。

### 🐧 Arch Linux 环境配置 (`.sh`)
* 🛠 **系统初始化**：初始化 Pacman 密钥环，更新镜像源及系统核心。
* 👤 **用户管理**：创建非 Root 用户并配置 `sudo` (wheel 组) 权限，设为默认登录用户。
* 🎨 **极致 Shell 体验**：预装 **Oh My Zsh** + `zsh-autosuggestions` (自动建议) + `zsh-syntax-highlighting` (语法高亮) + `z` (快速跳转)。
* 📦 **开箱即用 AUR**：自动编译并安装 **yay** (AUR 助手)，软件安装不再求人。
* 🐍 **开发环境**：预装并初始化 **Miniconda**。
* ✨ **生活质量**：预置 `nano`, `tmux`, `git`, `wget`, `curl` 等必备工具。

---

## ⚡ 快速开始 (懒人模式)

### 第一阶段：Windows 环境准备 (仅需一次)
*如果你还没有开启 WSL 或没安装 Arch，请执行此步。*

1.  下载本项目 (点击 **Code** -> **Download ZIP**) 并解压。
2.  双击运行 **`RunMe.bat`**。
    * *首次运行：* 它会开启 Windows 功能并提示你 **重启电脑**。
    * *重启后再次运行：* 它会自动下载、解压并注册安装 Arch Linux。

### 第二阶段：Linux 初始化 (一行神咒)
*当黑色的 Arch 终端窗口弹出后，复制粘贴下方这行命令并回车：*

```bash
pacman -Sy --noconfirm curl && bash <(curl -sL https://raw.githubusercontent.com/iris-Neko/Arch-WSL-One-Click/main/setup.sh)
```

## 📦 包含组件一览

| 组件类型 | 状态 | 详细说明 |
| :--- | :--- | :--- |
| **发行版** | 🟢 | Arch Linux (基于 ArchWSL) |
| **Shell** | 🟢 | Zsh + Oh My Zsh |
| **插件集** | 🟢 | `git`, `z`, `autosuggestions`, `syntax-highlighting` |
| **AUR 助手** | 🟢 | `yay` (脚本自动编译安装) |
| **Python** | 🟢 | Miniconda3 |
| **编辑器** | 🟢 | Nano (已设为默认) |
| **终端复用** | 🟢 | Tmux |

---

## 🛠 手动安装

如果你更喜欢完全掌控安装过程，或者想修改脚本内容：

1.  **开启 WSL**：在 Windows 功能中手动开启 WSL。
2.  **安装 ArchWSL**：从 [GitHub](https://github.com/yuk7/ArchWSL) 下载安装包。
3.  **克隆仓库**：进入 Arch 后执行：
    ```bash
    git clone https://github.com/iris-Neko/Arch-WSL-One-Click.git
    cd Arch-WSL-One-Click
    chmod +x setup.sh
    sudo ./setup.sh
    ```

---

## 🤝 贡献与反馈 (Contributing)

欢迎提交 Issues 和 Pull Requests！如果你有更好看的 Zsh 主题配置或者认为有必装的效率工具，欢迎推荐。

## 📄 开源协议 (License)

本项目基于 MIT 协议开源 - 详情请参阅 [LICENSE](LICENSE) 文件。

---
<p align="center">
  Made with ❤️ by <a href="https://github.com/iris-Neko">Iris-Neko</a>
</p>