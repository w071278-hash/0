@echo off
setlocal
title PROJECT AXIOM v1.1.0
echo.
echo ============================================================
echo   PROJECT AXIOM v1.1.0 - LAUNCHER
echo ============================================================
echo [INIT] 2026-02-13 20:15:00
ssh-keygen -R 15.204.238.67 >NUL 2>&1
echo [INIT] Handing off to PowerShell...
echo.

:: Set script directory for PowerShell to find modules
set "AXIOM_SCRIPT_DIR=%~dp0"

:: Call the standalone PowerShell script
set "PSFILE=%~dp0axiom.ps1"
if not exist "%PSFILE%" (
    echo [ERROR] Cannot find axiom.ps1 in the same directory as axiom.cmd
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%"
set EC=%ERRORLEVEL%
if %EC% NEQ 0 (
    echo.
    echo [FAIL] PowerShell exited with code %EC%
)
pause
exit /b %EC%
