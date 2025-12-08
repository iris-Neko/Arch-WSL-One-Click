# ==========================================
# Windows WSL + Arch Linux 全自动部署脚本 (优化版)
# ==========================================

# 1. 强制管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "请右键本脚本 -> 以管理员身份运行！" -ForegroundColor Red
    Read-Host "按 Enter 键退出..."
    Exit
}

$Green = "Green"; $Cyan = "Cyan"; $Yellow = "Yellow"; $Red = "Red"
Write-Host "=== Arch Linux on WSL 自动化部署工具 ===" -ForegroundColor $Cyan

# 定义目标发行版名称 (根据你的反馈，我们使用 ArchLinux)
$TargetDistro = "ArchLinux" 

# 2. 检查并开启 Windows 功能
Write-Host "`n[1/4] 检查 Windows 基础功能..." -ForegroundColor $Green
$wslStatus = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
$vmStatus = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

if ($wslStatus.State -ne "Enabled" -or $vmStatus.State -ne "Enabled") {
    Write-Host ">>> 正在开启 WSL 和 虚拟机平台..." -ForegroundColor $Yellow
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
    Write-Host "`n[严重警告] 功能已开启，必须重启电脑！" -ForegroundColor $Red
    Write-Host "请重启后再次运行此脚本。" -ForegroundColor $Red
    Read-Host "按 Enter 键重启 (或关闭窗口手动重启)..."
    Restart-Computer
    Exit
}

# 3. 配置 WSL 版本
Write-Host "`n[2/4] 配置 WSL 默认版本为 2..." -ForegroundColor $Green
try { wsl --update } catch { } # 尝试更新，失败忽略
wsl --set-default-version 2

# 4. 安装 Arch Linux
Write-Host "`n[3/4] 正在通过微软官方源安装 $TargetDistro ..." -ForegroundColor $Green

# 检测是否已存在（模糊匹配）
$existing = wsl --list --quiet | Select-String "Arch"
if ($existing) {
    Write-Host ">>> 检测到 Arch 似乎已经安装，跳过安装步骤。" -ForegroundColor $Yellow
} else {
    Write-Host ">>> 执行安装命令 (如下载慢请挂梯子)..." -ForegroundColor $Cyan
    try {
        # 关键：这里执行安装。
        # 注意：这通常会弹出一个新窗口进行初始化。
        wsl --install -d $TargetDistro
    } catch {
        Write-Host "安装命令执行出错：$_" -ForegroundColor $Red
        Read-Host "按 Enter 退出..."
        Exit
    }
}

# 5. 智能引导与启动 (你提到的重点优化部分)
Write-Host "`n[4/4] 环境后处理与启动..." -ForegroundColor $Green

# --- 逻辑优化：循环等待直到系统识别到发行版 ---
Write-Host ">>> 正在等待 WSL 注册完成..." -NoNewline
$maxRetries = 30
$detectedName = ""
for ($i = 0; $i -lt $maxRetries; $i++) {
    # 获取真实的发行版名称（防止是 ArchLinux 或者是 Arch）
    $list = wsl --list --quiet
    if ($list -match "(?i)Arch") { 
        # 提取匹配到的确切名称
        $detectedName = $list | Select-String "(?i)Arch" | Select-Object -First 1
        $detectedName = $detectedName.ToString().Trim() -replace "`0","" # 清洗字符
        Write-Host " [成功: $detectedName]" -ForegroundColor $Green
        break 
    }
    Start-Sleep -Seconds 2
    Write-Host "." -NoNewline
}

if (-not $detectedName) {
    Write-Host "`n[错误] 安装看似完成了，但系统列表中找不到 Arch。" -ForegroundColor $Red
    Write-Host "请尝试手动运行 'wsl -d ArchLinux' 看看是否成功。"
    Read-Host "按 Enter 退出..."
    Exit
}

# 准备神咒
$godCommand = "pacman -Sy --noconfirm curl && bash <(curl -sL https://raw.githubusercontent.com/iris-Neko/Arch-WSL-One-Click/refs/heads/main/git_setup.sh)"

Write-Host "`n--------------------------------------------------------" -ForegroundColor $Cyan
Write-Host "Arch Linux 即将启动！" -ForegroundColor $Cyan
Write-Host "请在 Linux 窗口出现 [root@...] 或 [$detectedName] 后，粘贴以下命令：" -ForegroundColor $Yellow
Write-Host "--------------------------------------------------------"
Write-Host $godCommand -ForegroundColor Green -BackgroundColor Black
Write-Host "--------------------------------------------------------"

# 写入剪贴板
try {
    Set-Clipboard -Value $godCommand
    Write-Host "(已自动复制到剪贴板，在黑窗口里 [右键] 即可粘贴)" -ForegroundColor $Green
} catch {
    Write-Host "(自动复制失败，请手动复制上面的命令)" -ForegroundColor $Red
}

# 清理缓冲区防止误触
while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }

Write-Host "`n>>> 按任意键，将在新窗口启动 $detectedName ..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# 使用 Start-Process 显式打开新窗口，确保和当前脚本分离
Start-Process wsl.exe -ArgumentList "-d $detectedName"

Write-Host "`n脚本运行结束。"
Start-Sleep -Seconds 3