@echo off
setlocal

REM =================================================================
REM 1. Force directory to current script location
REM    The "." at the end fixes the "cannot find drive" bug.
REM =================================================================
cd /d "%~dp0."

REM =================================================================
REM 2. Check for Admin rights and Elevate if needed
REM =================================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM =================================================================
REM 3. Run the PowerShell script
REM =================================================================
echo Admin privileges secured.
echo Working Directory: "%CD%"

if exist "auto_install_wsl.ps1" (
    echo Found script. Executing...
    powershell -NoProfile -ExecutionPolicy Bypass -File ".\auto_install_wsl.ps1"
) else (
    echo ERROR: auto_install_wsl.ps1 not found in this folder.
)

pause