# ==========================================
# Windows WSL + Arch Linux 全自动部署脚本
# ==========================================

# 1. 强制管理员权限 (必须放在最前面，否则 DISM 命令无法执行)
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "请右键本脚本 -> 以管理员身份运行！" -ForegroundColor Red
    Read-Host "按 Enter 键退出..."
    Exit
}

# 颜色定义
$Green = "Green"
$Cyan = "Cyan"
$Yellow = "Yellow"
$Red = "Red"

Write-Host "=== Arch Linux on WSL 自动化部署工具 ===" -ForegroundColor $Cyan

# 2. [恢复] 检查并开启 Windows 功能 (WSL & 虚拟机平台)
Write-Host "`n[1/4] 检查 Windows 基础功能..." -ForegroundColor $Green

$wslStatus = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
$vmStatus = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

if ($wslStatus.State -ne "Enabled" -or $vmStatus.State -ne "Enabled") {
    Write-Host ">>> 检测到 WSL 或 虚拟机平台 未开启，正在自动开启..." -ForegroundColor $Yellow
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    
    Write-Host "`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor $Red
    Write-Host "   警告：Windows 功能已开启，必须重启电脑才能生效！" -ForegroundColor $Red
    Write-Host "   PLEASE RESTART YOUR COMPUTER NOW." -ForegroundColor $Red
    Write-Host "   重启后，请再次双击运行此脚本继续安装 Arch。" -ForegroundColor $Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor $Red
    
    Write-Host "`n按任意键退出并准备重启..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
} else {
    Write-Host ">>> Windows 功能已就绪。" -ForegroundColor $Green
}

# 3. 更新 WSL 内核并设置默认版本为 2
Write-Host "`n[2/4] 配置 WSL 版本..." -ForegroundColor $Green
Write-Host ">>> 更新 WSL 内核..."
# 捕获可能的更新错误（防止网络问题中断脚本）
try { wsl --update } catch { Write-Host "更新跳过或失败，尝试继续..." -ForegroundColor Gray }
Write-Host ">>> 设置 WSL 2 为默认版本..."
wsl --set-default-version 2

# 4. [修改] 使用微软官方命令安装 Arch
Write-Host "`n[3/4] 正在安装 Arch Linux..." -ForegroundColor $Green

# 检查是否已经存在
if (wsl --list --quiet | Select-String "Arch") {
    Write-Host ">>> 检测到 Arch 似乎已经安装。" -ForegroundColor $Yellow
} else {
    Write-Host ">>> 正在执行 wsl --install -d Arch ..." -ForegroundColor $Cyan
    try {
        wsl --install -d archlinux
    } catch {
        Write-Host "安装命令报错！" -ForegroundColor $Red
        Read-Host "按 Enter 键退出查看错误..."
        Exit
    }
}

# 5. 引导用户运行 Linux 内部脚本
Write-Host "`n[4/4] 准备就绪！" -ForegroundColor $Green
Write-Host "--------------------------------------------------------" -ForegroundColor $Cyan
Write-Host "Arch Linux 终端即将打开。" -ForegroundColor $Cyan
Write-Host "请在打开的窗口出现 [root@...] 后，粘贴你的一键神咒：" -ForegroundColor $Yellow
Write-Host "--------------------------------------------------------"

# 你的原版神咒 (既然官方包自带 Keyring 配置，这里用回你原来的命令)
$godCommand = "pacman -Sy --noconfirm curl && bash <(curl -sL https://raw.githubusercontent.com/iris-Neko/Arch-WSL-One-Click/refs/heads/main/git_setup.sh)"

Write-Host $godCommand -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "--------------------------------------------------------"
Set-Clipboard -Value $godCommand
Write-Host "(已自动复制到剪贴板，直接在 Arch 窗口里点右键粘贴即可)" -ForegroundColor $Green

Write-Host "`n按任意键启动 Arch..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# 启动 Arch (尝试用 wsl 命令启动，比调用 exe 更通用)
wsl -d archlinux

# 防止窗口一闪而过
Write-Host "`n=========================="
Write-Host "脚本运行结束。"
Read-Host -Prompt "按 Enter 键退出..."