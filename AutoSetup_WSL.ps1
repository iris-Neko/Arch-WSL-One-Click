# ==========================================
# Windows WSL + Arch Linux 全自动部署脚本
# ==========================================

# 颜色定义
$Green = "Green"
$Cyan = "Cyan"
$Yellow = "Yellow"
$Red = "Red"

Write-Host "=== Arch Linux on WSL 自动化部署工具 ===" -ForegroundColor $Cyan

# 1. 检查并开启 Windows 功能 (WSL & 虚拟机平台)
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

# 2. 更新 WSL 内核并设置默认版本为 2
Write-Host "`n[2/4] 配置 WSL 版本..." -ForegroundColor $Green
Write-Host ">>> 更新 WSL 内核..."
wsl --update
Write-Host ">>> 设置 WSL 2 为默认版本..."
wsl --set-default-version 2

# 3. 自动下载并安装 ArchWSL (使用 Yuk7 版本)
$installPath = "$env:USERPROFILE\ArchWSL"
$zipUrl = "https://github.com/yuk7/ArchWSL/releases/latest/download/Arch.zip"
$zipPath = "$installPath\Arch.zip"

if (Test-Path "$installPath\Arch.exe") {
    Write-Host "`n[3/4] 检测到 Arch 似乎已经安装在 $installPath" -ForegroundColor $Yellow
    Write-Host ">>> 跳过下载安装步骤。"
} else {
    Write-Host "`n[3/4] 正在下载安装 Arch Linux (Yuk7/ArchWSL)..." -ForegroundColor $Green
    
    # 创建安装目录
    if (-not (Test-Path $installPath)) { New-Item -ItemType Directory -Force -Path $installPath | Out-Null }
    
    # 下载
    Write-Host ">>> 正在下载 Arch.zip (可能需要一点时间)..." -ForegroundColor $Cyan
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        Write-Host "下载失败！请检查网络连接（GitHub 可能被墙）。" -ForegroundColor $Red
        Pause
        exit
    }

    # 解压
    Write-Host ">>> 正在解压..." -ForegroundColor $Cyan
    Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
    
    # 清理压缩包
    Remove-Item $zipPath
    
    # 注册安装
    Write-Host ">>> 正在初始化 Arch (注册到 WSL)..." -ForegroundColor $Cyan
    Start-Process -FilePath "$installPath\Arch.exe" -Wait
    
    Write-Host ">>> Arch 安装完成！" -ForegroundColor $Green
}

# 4. 引导用户运行 Linux 内部脚本
Write-Host "`n[4/4] 准备就绪！" -ForegroundColor $Green
Write-Host "--------------------------------------------------------" -ForegroundColor $Cyan
Write-Host "Arch Linux 终端即将打开。" -ForegroundColor $Cyan
Write-Host "请在打开的黑色窗口中，粘贴你的一键神咒：" -ForegroundColor $Yellow
Write-Host "--------------------------------------------------------"
# 这里把你的神咒打印出来方便复制，注意替换成你的真实 URL
$godCommand = "pacman -Sy --noconfirm curl && bash <(curl -sL https://gist.githubusercontent.com/iris-Neko/99588898da3e930d727a4398477433f6/raw/setup.sh)"
Write-Host $godCommand -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "--------------------------------------------------------"
Set-Clipboard -Value $godCommand
Write-Host "(已自动复制到剪贴板，直接在 Arch 窗口里点右键粘贴即可)" -ForegroundColor $Green

Write-Host "`n按任意键启动 Arch..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# 启动 Arch
& "$installPath\Arch.exe"