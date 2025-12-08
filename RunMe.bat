@echo off
setlocal EnableDelayedExpansion
title WSL自动安装向导 (AutoSetup_WSL Launcher)

:: ==============================
:: 配置区域
:: ==============================
set "TargetScript=AutoSetup_WSL.ps1"

:: ==============================
:: 1. 环境准备与路径修正
:: ==============================
:: 强制切换到 bat 文件所在的目录 (解决管理员模式下默认路径为 System32 的问题)
cd /d "%~dp0"

:: ==============================
:: 2. 检查管理员权限
:: ==============================
:: 使用 fsutil dirty query 检查权限 (比 cacls 更快更干净)
>nul 2>&1 fsutil dirty query %systemdrive%

if '%errorlevel%' NEQ '0' (
    echo [INFO] 当前非管理员权限，正在尝试提权...
    echo [INFO] 请在弹出的 UAC 窗口中点击“是”...
    
    :: 重新启动自己，并申请 RunAs (管理员) 权限
    :: 传递原始参数 (虽然 WSL 安装通常不需要参数，但保留此功能以备扩展)
    powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    
    :: 提权后旧窗口退出
    exit /b
)

:: ==============================
:: 3. 执行前检查 (鲁棒性核心)
:: ==============================
echo [INFO] 已获得管理员权限.
echo [INFO] 工作目录: "%~dp0"

if not exist ".\%TargetScript%" (
    echo.
    echo [ERROR] 致命错误: 找不到脚本文件!
    echo [ERROR] 请确保 "%TargetScript%" 位于当前文件夹中:
    echo         "%~dp0"
    echo.
    pause
    exit /b 1
)

:: ==============================
:: 4. 启动 PowerShell 脚本
:: ==============================
echo [INFO] 正在启动 %TargetScript% ...
echo -----------------------------------------------------------

:: 关键参数解释:
:: -NoProfile: 不加载用户配置文件 (加快启动速度，避免环境干扰)
:: -ExecutionPolicy Bypass: 临时绕过脚本执行策略 (不修改系统全局设置)
:: -File: 明确指定运行文件，防止路径解析错误
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\%TargetScript%"

:: ==============================
:: 5. 结束处理
:: ==============================
echo.
echo -----------------------------------------------------------
echo [INFO] 脚本执行结束.
echo.
pause