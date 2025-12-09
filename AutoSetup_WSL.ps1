<#
WSL ArchLinux 自动配置脚本
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============ 日志 ============
function Write-Log {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

# ============ RunOnce 清理 ============
function Clean-RunOnceRegistry {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $name = "WSL_AutoSetup_Continue"
    if (Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue
        Write-Log "已清理 RunOnce 项。" "Green"
    }
}
# ============ 主流程 ============
function Main {
    Write-Log "=== ArchLinux 自动化配置阶段 ===" "Magenta"

    Clean-RunOnceRegistry

    wt.exe -w new wsl -d ArchLinux -u root bash -lc "pacman -Sy --noconfirm curl && bash <(curl -sL https://raw.githubusercontent.com/iris-Neko/Arch-WSL-One-Click/refs/heads/main/setup.sh)"

    Write-Log "=== 所有配置脚本执行完毕 ===" "Green"
    Read-Host "按回车键退出..."
}

Main
