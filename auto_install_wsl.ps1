<#
.SYNOPSIS
    WSL ArchLinux 自动化安装脚本 (非阻塞监测版)
    
.DESCRIPTION
    1. 启动独立窗口运行 wsl --install -d archlinux。
    2. 主线程不等待窗口关闭，而是轮询 wsl --list --quiet。
    3. 一旦检测到 "Arch" 关键字，视为安装成功。
    4. 首次安装（无WSL组件）：检测到进程结束或安装成功后，注册 RunOnce 并重启。
    5. 非首次安装：直接运行 AutoSetup_WSL.ps1。

.NOTES
    编码: UTF-8
#>

# ==========================================
# 1. 初始化与编码设置
# ==========================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Script:CurrentDir = $PSScriptRoot
$Script:AutoSetupFile = Join-Path -Path $Script:CurrentDir -ChildPath "AutoSetup_WSL.ps1"

# ==========================================
# 2. 功能函数封装
# ==========================================

function Write-Log {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

function Test-WSLComponentInstalled {
    <#
    .DESCRIPTION
        通过 wsl --status 返回值判断 WSL 核心组件是否存在。
        如果 wsl.exe 只是个桩(Stub)，--status 会报错或返回非0。
    #>
    try {
        if (-not (Get-Command "wsl" -ErrorAction SilentlyContinue)) { return $false }
        $null = wsl --status 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Register-RunOnce {
    <#
    .DESCRIPTION
        注册重启后自动运行 AutoSetup_WSL.ps1
    #>
    param([string]$ScriptPath)
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $regName = "WSL_AutoSetup_Continue"
    $cmd = "powershell.exe -NoProfile -WindowStyle Normal -ExecutionPolicy Bypass -File `"$ScriptPath`""
    
    try {
        Set-ItemProperty -Path $regPath -Name $regName -Value $cmd -ErrorAction Stop
        Write-Log ">> [注册表] 已添加重启自启动项。" "Green"
    } catch {
        Write-Log ">> [错误] 写入注册表失败，请尝试管理员运行。" "Red"
    }
}

function Monitor-Installation {
    <#
    .DESCRIPTION
        核心监测逻辑：
        不等待进程结束（因为会进Shell），而是监测 wsl --list --quiet 是否出现 Arch。
        同时监测进程是否意外退出。
    #>
    param([System.Diagnostics.Process]$InstallProcess)

    Write-Log "正在后台监测安装进度 (目标: Arch)..." "Cyan"
    
    $maxRetries = 6000 # 约 200-300 分钟超时
    $counter = 0
    $spinner = @("|", "/", "-", "\")
    
    while ($counter -lt $maxRetries) {
        Start-Sleep -Seconds 2
        
        # 1. 核心检测：检查 wsl 列表
        # 使用 --quiet 避免编码干扰，PowerShell 会处理为 UTF-16LE -> String
        $listOutput = (wsl --list --quiet 2>$null) -join " "
        
        if ($listOutput -match "Arch") {
            Write-Host "`r" # 清除动画
            return "Success"
        }

        # 2. 进程状态检测 (针对首次安装需要重启的情况)
        # 如果安装窗口已经关了，但列表里还没 Arch，说明可能是要求重启的阶段
        if ($InstallProcess.HasExited) {
            Write-Host "`r"
            Write-Log "安装窗口已关闭。" "Yellow"
            return "ProcessExited"
        }

        # 动画效果
        Write-Host "`r[$($spinner[$counter % 4])] 等待 Arch 注册中..." -NoNewline -ForegroundColor DarkGray
        $counter++
    }

    return "Timeout"
}

function New-CredentialFile {
    <#
    .DESCRIPTION
        询问用户名和密码，并保存到当前目录下的 wsl_cred.txt
        格式为: username:password
    #>
    param([string]$FileName = "wsl_cred.txt")
    
    $filePath = Join-Path -Path $Script:CurrentDir -ChildPath $FileName
    
    # 如果文件已存在，询问是否覆盖，或者直接跳过
    if (Test-Path $filePath) {
        Write-Log "检测到凭证文件 $FileName 已存在，跳过生成。" "Yellow"
        return
    }

    Write-Host "`n=== 配置 WSL 用户凭证 ===" -ForegroundColor Magenta
    
    # 获取用户名，不能为空
    do {
        $user = Read-Host "请输入要创建的 WSL 用户名"
    } while ([string]::IsNullOrWhiteSpace($user))

    # 获取密码 (SecureString 转 PlainText，或者直接 Read-Host，为了写入文件这里简化处理)
    # 注意：为了脚本自动化，这里存的是明文。请确保此文件后续被删除或妥善保管。
    do {
        $pass = Read-Host "请输入该用户的密码"
    } while ([string]::IsNullOrWhiteSpace($pass))

    # 格式化内容: username:password
    # 注意：使用 UTF8 编码，并不带 BOM (PowerShell Core 默认无BOM，5.1需注意，这里用 ASCII 或 UTF8 均可，只要英文)
    $content = "$user`:$pass"
    
    try {
        # 强制不带 BOM 的 UTF8 (为了 Linux 读取更方便)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllText($filePath, $content, $utf8NoBom)
        
        Write-Log "凭证文件已生成: $filePath" "Green"
    }
    catch {
        Write-Log "生成凭证文件失败: $_" "Red"
        exit 1
    }
}


# ==========================================
# 3. 主程序逻辑
# ==========================================

function Main {
    Write-Log ">>> 开始 WSL ArchLinux 部署" "Magenta"
    # [新增] 1. 先生成凭证文件，确保后续 setup.sh 能用到
    New-CredentialFile
    # 检查 AutoSetup 文件
    if (-not (Test-Path $Script:AutoSetupFile)) {
        Write-Log "提示: 当前目录下没找到 AutoSetup_WSL.ps1，建议创建。" "Yellow"
    }

    # 判断是否为首次安装（无 WSL 组件）
    $isFirstTime = -not (Test-WSLComponentInstalled)

    if ($isFirstTime) {
        Write-Log "模式: [首次安装] - 系统未检测到 WSL 组件" "Magenta"
        Write-Log "即将注册重启任务..." "Gray"
        Register-RunOnce -ScriptPath $Script:AutoSetupFile
    } else {
        Write-Log "模式: [增量安装] - WSL 组件已就绪" "Magenta"
        # 如果已经有 Arch 了，直接跳去运行 Setup
        if ((wsl --list --quiet 2>$null) -match "Arch") {
            Write-Log "检测到 Arch 已存在，跳过安装，直接运行配置。" "Green"
            & $Script:AutoSetupFile
            return
        }
    }

    # --- 启动安装 (独立窗口) ---
    Write-Log "启动新窗口运行: wsl --install -d archlinux" "Cyan"
    # 关键：使用 PassThru 获取进程对象，用于判断窗口是否意外关闭
    $proc = Start-Process wsl -ArgumentList "--install -d archlinux" -WindowStyle Normal -PassThru

    # --- 开始非阻塞监测 ---
    $result = Monitor-Installation -InstallProcess $proc

    # --- 结果处理 ---
    if ($result -eq "Success") {
        Write-Log "检测到 ArchLinux 已成功注册！" "Green"
        
        if ($isFirstTime) {
            # 即使注册成功了，如果是 FirstTime，通常 Windows 仍要求重启才能使 WSL2 功能完整生效
            Write-Log "虽然安装已完成，但这是首次启用 WSL，强烈建议重启。" "Yellow"
            $choice = Read-Host "是否立即重启? (y/n)"
            if ($choice -eq 'y') { Restart-Computer }
        } else {
            # 非首次，直接运行后续脚本
            Write-Log "正在启动 AutoSetup_WSL.ps1 ..." "Green"
            Start-Sleep -Seconds 1
            & $Script:AutoSetupFile
        }
    }
    elseif ($result -eq "ProcessExited") {
        if ($isFirstTime) {
            Write-Log "安装程序已退出（可能是完成了组件下载并提示重启）。" "Yellow"
            Write-Log "已配置自动启动，请重启电脑以完成剩余步骤。" "Yellow"
            $choice = Read-Host "是否立即重启? (y/n)"
            if ($choice -eq 'y') { Restart-Computer }
        } else {
            Write-Log "安装窗口已关闭，但未检测到 Arch 注册。可能安装失败或用户取消。" "Red"
        }
    }
    else {
        Write-Log "等待超时。请检查安装窗口是否有报错。" "Red"
    }
}

# 运行入口
Main