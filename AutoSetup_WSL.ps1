<#
.SYNOPSIS
    WSL ArchLinux 后续配置脚本
.DESCRIPTION
    1. 清理注册表 RunOnce 残留（防止下次重启重复运行）。
    2. 初始化 ArchLinux 的 pacman keyring。
    3. 将当前 Windows 目录下的 setup.sh 转换为 Linux 格式并执行。
.NOTES
    编码: UTF-8
#>

# ==========================================
# 1. 初始化设置
# ==========================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Script:CurrentDir = $PSScriptRoot
$Script:SetupShellFile = Join-Path -Path $Script:CurrentDir -ChildPath "setup.sh"

# ==========================================
# 2. 功能函数
# ==========================================

function Write-Log {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

function Clean-RunOnceRegistry {
    <#
    .DESCRIPTION
        清理注册表 RunOnce 项，防止无限重启循环执行。
        虽然 RunOnce 运行后系统会自动删，但手动清理更保险。
    #>
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $regName = "WSL_AutoSetup_Continue"
    try {
        if (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
            Write-Log "已清理注册表 RunOnce 自启动项。" "Green"
        }
    } catch {
        Write-Log "尝试清理注册表项失败，但这不影响后续运行。" "Yellow"
    }
}

function Init-Arch-Keyring {
    <#
    .DESCRIPTION
        初始化 Pacman Keyring，解决签名错误问题。
    #>
    Write-Log "正在初始化 Arch Keyring (这可能需要几分钟)..." "Cyan"
    
    # 组合命令：初始化 -> 填充 -> 刷新(可选，这里只做基础填充)
    # 注意：这里使用 root 用户运行
    $cmd = "pacman-key --init && pacman-key --populate archlinux"
    
    wsl -d archlinux -u root -- exec bash -c $cmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Keyring 初始化完成。" "Green"
    } else {
        Write-Log "Keyring 初始化遇到错误，请检查网络或稍后手动尝试。" "Red"
    }
}

function Invoke-SetupShellScript {
    <#
    .DESCRIPTION
        在 WSL 内部执行 Windows 目录下的 setup.sh。
        自动处理：路径转换、CRLF 换行符修复、权限赋予。
    #>
    param([string]$WinPath)

    if (-not (Test-Path $WinPath)) {
        Write-Log "错误：未在当前目录下找到 setup.sh 文件！" "Red"
        return
    }

    Write-Log "准备执行脚本: setup.sh" "Cyan"

    # 构建复杂的 Bash 命令字符串
    # 1. wslpath: 把 Windows 路径转为 /mnt/c/...
    # 2. sed: 去除 \r 字符 (CRLF -> LF)，防止 '/bin/bash^M: bad interpreter' 错误
    # 3. chmod: 赋予执行权限
    # 4. bash: 执行脚本
    
    # 注意：这里使用单引号包裹 Windows 路径，防止特殊字符问题
    $bashScript = @"
    echo '>>> [WSL] 正在定位文件...'
    LINUX_PATH=`$(wslpath '$WinPath')
    echo "Target: `$LINUX_PATH"

    echo '>>> [WSL] 正在修复换行符 (CRLF fix)...'
    sed -i 's/\r$//' "`$LINUX_PATH"

    echo '>>> [WSL] 赋予执行权限...'
    chmod +x "`$LINUX_PATH"

    echo '>>> [WSL] 开始执行 setup.sh ...'
    echo '----------------------------------------'
    bash "`$LINUX_PATH"
"@

    # 执行命令
    wsl -d archlinux -u root -- exec bash -c $bashScript
}

# ==========================================
# 3. 主逻辑
# ==========================================

function Main {
    Write-Log "=== ArchLinux 自动化配置阶段 ===" "Magenta"

    # 1. 清理痕迹
    Clean-RunOnceRegistry

    # 2. 确保 WSL 处于活跃状态 (防止刚重启 WSL 未响应)
    Write-Log "正在连接 WSL 子系统..." "Gray"
    wsl -d archlinux -u root -- exec echo "WSL Ready" | Out-Null

    # 3. 初始化密钥环
    Init-Arch-Keyring

    # 4. 执行 setup.sh
    Invoke-SetupShellScript -WinPath $Script:SetupShellFile

    Write-Log "=== 所有配置脚本执行完毕 ===" "Green"
    Write-Log "现在您可以安全关闭此窗口。" "Gray"
    Read-Host "按回车键退出..."
}

Main