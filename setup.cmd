@echo off
title AXIOM SETUP
echo.
echo ============================================================
echo   AXIOM - ONE TIME SETUP
echo ============================================================
echo.
echo Cloning repository to your Desktop...
echo.
cd /d "%USERPROFILE%\Desktop"
if exist "axiom" (
    echo [INFO] axiom folder already exists, updating...
    cd axiom
    git pull
) else (
    git clone https://github.com/w071278-hash/0.git axiom
    cd axiom
)
echo.
echo ============================================================
echo   SETUP COMPLETE - Launching Axiom...
echo ============================================================
echo.
call axiom.cmd