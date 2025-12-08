@echo off
:: 获取脚本当前目录
cd /d "%~dp0"

:: 检查是否具有管理员权限，如果没有则尝试提权
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

if '%errorlevel%' NEQ '0' (
    echo 请求管理员权限运行...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    :: 下面这一行会调用 PowerShell 脚本，
    echo UAC.ShellExecute "powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File ""%~dp0AutoSetup_WSL.ps1""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    echo 已获取管理员权限
    :: 如果逻辑走到这里，通常是已经是管理员直接运行 bat 的情况
    PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0AutoSetup_WSL.ps1"