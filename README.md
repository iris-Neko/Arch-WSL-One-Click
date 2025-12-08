# 🚀 Arch WSL Bootstrap

> **Zero to Hero:** From a fresh Windows installation to a fully configured Arch Linux development environment in minutes.

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-Distro-blue?logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![WSL 2](https://img.shields.io/badge/Platform-WSL2-orange?logo=windows&logoColor=white)](https://docs.microsoft.com/en-us/windows/wsl/)
[![PowerShell](https://img.shields.io/badge/Script-PowerShell-5391FE?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![中文文档](https://img.shields.io/badge/文档-中文版-blue.svg)](./README_CN.md)
![Terminal Preview](screenshot.png)

## 📖 Introduction

**Stop wasting time configuring Linux manually.**

This repository provides a complete **Infrastructure as Code (IaC)** solution for Windows Subsystem for Linux (WSL). It automates the entire lifecycle:

1.  **Windows Side:** Auto-enables WSL features, updates kernels, and installs Arch Linux (ArchWSL).
2.  **Linux Side:** Auto-configures Users, Sudo, Pacman, AUR (yay), Zsh, Plugins, and Conda.

**Perfect for:** Developers who want a reproducible, disposable, and instant Arch environment.

---

## ✨ Features

### 🖥️ Windows Automation (`.ps1`)
* ✅ **Auto-Enable WSL 2**: Checks and enables `Microsoft-Windows-Subsystem-Linux` & `VirtualMachinePlatform`.
* ✅ **Auto-Download Arch**: Fetches the latest [Yuk7/ArchWSL](https://github.com/yuk7/ArchWSL) release.
* ✅ **One-Click Deploy**: Bypasses PowerShell execution policies via a helper `.bat` file.

### 🐧 Arch Linux Configuration (`.sh`)
* 🛠 **System Prep**: Initializes Pacman keys, updates mirrors & system.
* 👤 **User Setup**: Creates a non-root user with `sudo` privileges (wheel group).
* 🎨 **Shell Experience**: Installs **Oh My Zsh** + `zsh-autosuggestions` + `zsh-syntax-highlighting` + `z`.
* 📦 **AUR Ready**: Automatically compiles and installs **yay** (AUR Helper).
* 🐍 **Dev Environment**: Installs and initializes **Miniconda**.
* ✨ **Quality of Life**: Pre-configures `nano`, `tmux`, `git`, `wget`, `curl`.

---

## ⚡ Quick Start (The "Lazy" Way)

### Phase 1: Windows Setup (One-Time)
*Use this if you haven't enabled WSL or installed Arch yet.*

1.  Download this repository (Click **Code** -> **Download ZIP**) and extract it.
2.  Double-click **`RunMe.bat`**.
    * *First run:* It will enable Windows features and ask you to **Reboot**.
    * *Second run (after reboot):* It will download and install Arch Linux automatically.

### Phase 2: Linux Initialization (The Magic Spell)
*Once your black Arch terminal window opens, run this single command to set up everything:*

```bash
pacman -Sy --noconfirm curl && bash <(curl -sL https://raw.githubusercontent.com/iris-Neko/Arch-WSL-One-Click/main/setup.sh)
```

## 📦 What's Inside?

| Component | Status | Details |
| :--- | :--- | :--- |
| **Distro** | 🟢 | Arch Linux (via ArchWSL) |
| **Shell** | 🟢 | Zsh + Oh My Zsh |
| **Plugins** | 🟢 | `git`, `z`, `autosuggestions`, `syntax-highlighting` |
| **AUR Helper** | 🟢 | `yay` (Auto-compiled) |
| **Python** | 🟢 | Miniconda3 |
| **Editor** | 🟢 | Nano (Default) |
| **Multiplexer** | 🟢 | Tmux |

---

## 🛠 Manual Installation

If you prefer to do things manually or modify the scripts:

1.  **Enable WSL** manually in Windows Features.
2.  **Install ArchWSL** from [GitHub](https://github.com/yuk7/ArchWSL).
3.  **Clone this repo** inside Arch:
    ```bash
    git clone https://github.com/iris-Neko/Arch-WSL-One-Click.git
    cd Arch-WSL-One-Click
    chmod +x setup.sh
    sudo ./setup.sh
    ```

---

## 🤝 Contributing

Issues and Pull Requests are welcome! If you have a better Zsh theme or more essential tools, feel free to suggest.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
<p align="center">
  Made with ❤️ by <a href="https://github.com/iris-Neko">Iris-Neko</a>
</p>