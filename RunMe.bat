@echo off
:: 设置控制台为 UTF-8 编码，支持 emoji 和中文
chcp 65001 > nul
setlocal

:: -------------------------------------------------------------
:: 1. 管理员权限检测与自动提权模块
:: -------------------------------------------------------------
:: 尝试执行一个只有管理员才能执行的命令 (net session)
net session >nul 2>&1

:: 如果错误码(errorlevel)不为 0，说明没有管理员权限
if %errorlevel% neq 0 (
    echo 正在请求管理员权限... 🛡️
    :: 使用 PowerShell 的 Start-Process -Verb RunAs 重新运行当前 bat 脚本
    powershell -Command "Start-Process cmd -ArgumentList '/c, \"%~f0\"' -Verb RunAs"
    exit /b
)

:: -------------------------------------------------------------
:: 2. 环境准备
:: -------------------------------------------------------------
:: 关键步骤：切换工作目录到脚本当前所在的文件夹
:: 如果不加这一行，提权后默认目录会变成 C:\Windows\System32，导致找不到 ps1 文件
cd /d "%~dp0"

echo 提权成功! ✅ 这是一只猫：🐈
echo.

:: 定义你的 PowerShell 脚本文件名 (如果名字不同，请在这里修改)
set "SCRIPT_NAME=auto_install_wsl.ps1"

:: -------------------------------------------------------------
:: 3. 执行 PowerShell 脚本
:: -------------------------------------------------------------
if exist "%SCRIPT_NAME%" (
    echo 正在调用 PowerShell 脚本监控安装...
    echo.
    :: -ExecutionPolicy Bypass: 临时绕过执行策略，防止脚本被禁止运行
    :: -File: 指定要运行的文件
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_NAME%"
) else (
    echo ❌ 错误：找不到文件 "%SCRIPT_NAME%"
    echo 请确保 bat 和 ps1 文件在同一个目录下！
    pause
)