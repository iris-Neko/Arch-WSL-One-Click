@echo off
cd /d "%~dp0"
echo Requesting Administrator privileges...
:: 自动申请管理员权限运行 PowerShell 脚本
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0AutoSetup_WSL.ps1""' -Verb RunAs}"
exit