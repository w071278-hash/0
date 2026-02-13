@echo off
setlocal enabledelayedexpansion

:: ============================================================================
::  AXIOM v1.1.0 - DEPLOYMENT CONTROLLER FOR WINDOWS
:: ============================================================================
::  Complete orchestration script with pre-flight checks, SSH key management,
::  and guided deployment workflow.
:: ============================================================================

set VERSION=1.1.0
set REPO_URL=https://github.com/w071278-hash/0
set DEFAULT_USER=ubuntu
set SSH_KEY_NAME=id_ed25519_vps_2026

title Axiom v%VERSION% Deployment Controller

:: --- COLORS (Windows 10+ ANSI support) ---
set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "CYAN=[96m"
set "RESET=[0m"

echo.
echo %CYAN%========================================%RESET%
echo %CYAN%  AXIOM v%VERSION% Deployment Controller%RESET%
echo %CYAN%========================================%RESET%
echo.

:: ============================================================================
:: PHASE 1: PRE-FLIGHT CHECKS
:: ============================================================================

echo %CYAN%[PHASE 1] Pre-flight Checks%RESET%
echo.

:: --- Check 1: Git ---
echo [1/5] Checking for Git...
where git >nul 2>&1
if errorlevel 1 (
    echo %RED%[FAIL] Git is not installed or not in PATH%RESET%
    echo.
    echo Please install Git for Windows from: https://git-scm.com/download/win
    echo After installation, restart this script.
    pause
    exit /b 1
)
echo %GREEN%[OK] Git found%RESET%

:: --- Check 2: SSH ---
echo [2/5] Checking for SSH...
where ssh >nul 2>&1
if errorlevel 1 (
    echo %RED%[FAIL] SSH is not available%RESET%
    echo.
    echo OpenSSH should be built into Windows 10/11.
    echo Enable it via: Settings ^> Apps ^> Optional Features ^> OpenSSH Client
    pause
    exit /b 1
)
echo %GREEN%[OK] SSH found%RESET%

:: --- Check 3: Repository ---
echo [3/5] Checking repository status...
if not exist ".git" (
    echo %RED%[FAIL] Not in a git repository%RESET%
    echo.
    echo Please run this script from the root of the Axiom repository.
    echo If you haven't cloned it yet:
    echo   git clone %REPO_URL%
    echo   cd 0
    echo   .\axiom.cmd
    pause
    exit /b 1
)
echo %GREEN%[OK] Repository detected%RESET%

:: --- Check 4: Modules directory ---
echo [4/5] Checking for deployment modules...
if not exist "modules\00-config.sh" (
    echo %RED%[FAIL] Deployment modules not found%RESET%
    echo.
    echo The modules directory is missing or incomplete.
    echo Try: git pull
    pause
    exit /b 1
)
echo %GREEN%[OK] Deployment modules found%RESET%

:: --- Check 5: Internet connectivity ---
echo [5/5] Checking internet connectivity...
ping -n 1 8.8.8.8 >nul 2>&1
if errorlevel 1 (
    echo %YELLOW%[WARN] Internet connectivity test failed%RESET%
    echo This may cause issues during deployment.
    echo.
    choice /C YN /M "Continue anyway?"
    if errorlevel 2 exit /b 1
) else (
    echo %GREEN%[OK] Internet connectivity confirmed%RESET%
)

echo.
echo %GREEN%All pre-flight checks passed!%RESET%
echo.
pause

:: ============================================================================
:: PHASE 2: SSH KEY DISCOVERY AND SETUP
:: ============================================================================

echo.
echo %CYAN%[PHASE 2] SSH Key Discovery%RESET%
echo.

set SSH_DIR=%USERPROFILE%\.ssh
set SSH_KEY=%SSH_DIR%\%SSH_KEY_NAME%

:: Check if the default key exists
if exist "%SSH_KEY%" (
    echo %GREEN%[OK] Found existing SSH key: %SSH_KEY_NAME%%RESET%
    goto :test_connection
)

echo %YELLOW%[INFO] Default key not found: %SSH_KEY_NAME%%RESET%
echo.

:: Check for any existing keys
echo Looking for existing SSH keys in %SSH_DIR%...
if not exist "%SSH_DIR%" mkdir "%SSH_DIR%"

set KEY_COUNT=0
set KEY_LIST=

for %%f in ("%SSH_DIR%\id_*") do (
    set /a KEY_COUNT+=1
    set KEY_LIST=!KEY_LIST! %%~nxf
)

if %KEY_COUNT% gtr 0 (
    echo.
    echo Found %KEY_COUNT% existing key(s):
    echo %KEY_LIST%
    echo.
    choice /C YN /M "Use an existing key?"
    if not errorlevel 2 (
        echo.
        echo Enter the key filename ^(e.g., id_ed25519^):
        set /p CHOSEN_KEY=^> 
        if exist "%SSH_DIR%\!CHOSEN_KEY!" (
            set SSH_KEY=%SSH_DIR%\!CHOSEN_KEY!
            echo %GREEN%Using key: !CHOSEN_KEY!%RESET%
            goto :test_connection
        ) else (
            echo %RED%Key not found. Proceeding to generate new key.%RESET%
        )
    )
)

:: Generate new SSH key
echo.
echo %CYAN%Generating new SSH key: %SSH_KEY_NAME%%RESET%
echo.
ssh-keygen -t ed25519 -f "%SSH_KEY%" -N "" -C "axiom-deployment"

if errorlevel 1 (
    echo %RED%[FAIL] Failed to generate SSH key%RESET%
    pause
    exit /b 1
)

echo %GREEN%[OK] New SSH key generated%RESET%
echo.

:: Display the public key
echo %CYAN%Your PUBLIC key (safe to share):%RESET%
echo ----------------------------------------
type "%SSH_KEY%.pub"
echo ----------------------------------------
echo.

:: Copy to clipboard if possible
clip < "%SSH_KEY%.pub" 2>nul
if not errorlevel 1 (
    echo %GREEN%[OK] Public key copied to clipboard%RESET%
)

echo.
echo %CYAN%========================================%RESET%
echo %CYAN%  SSH KEY DEPLOYMENT OPTIONS%RESET%
echo %CYAN%========================================%RESET%
echo.
echo You have two options to deploy your SSH key to the VPS:
echo.
echo   [P] Paste into VPS Provider ^(RECOMMENDED^)
echo       - Copy the key above into your VPS provider's control panel
echo       - Works with OVH, Hetzner, DigitalOcean, Vultr, etc.
echo       - Most secure method
echo.
echo   [D] Deploy via Password SSH ^(ALTERNATIVE^)
echo       - Requires password authentication enabled on VPS
echo       - Less secure, only use if provider doesn't support key paste
echo.
choice /C PD /M "Select deployment method"

if errorlevel 2 goto :password_deploy
if errorlevel 1 goto :paste_deploy

:paste_deploy
echo.
echo %CYAN%========================================%RESET%
echo %CYAN%  PASTE KEY INTO VPS PROVIDER%RESET%
echo %CYAN%========================================%RESET%
echo.
echo STEP-BY-STEP INSTRUCTIONS:
echo.
echo   1. Log into your VPS provider's control panel
echo.
echo   2. Find the SSH key management section:
echo      - OVH: Control Panel ^> Public Cloud ^> SSH Keys
echo      - Hetzner: Cloud Console ^> Security ^> SSH Keys
echo      - DigitalOcean: Settings ^> Security ^> SSH Keys
echo      - Vultr: Account ^> SSH Keys
echo.
echo   3. Click "Add SSH Key" or similar button
echo.
echo   4. Paste the public key ^(already in your clipboard^)
echo.
echo   5. Give it a name ^(e.g., "Axiom Deployment Key"^)
echo.
echo   6. When creating your VPS, SELECT THIS KEY
echo.
echo   7. Note the VPS IP address after creation
echo.
echo.
echo %YELLOW%Your public key is still in the clipboard!%RESET%
echo If needed, here it is again:
echo.
type "%SSH_KEY%.pub"
echo.
echo.
pause
echo.
goto :get_vps_info

:password_deploy
echo.
echo %YELLOW%========================================%RESET%
echo %YELLOW%  PASSWORD SSH DEPLOYMENT%RESET%
echo %YELLOW%========================================%RESET%
echo.
echo %YELLOW%WARNING: This method is less secure than pasting the key.%RESET%
echo Use this only if your VPS provider doesn't support key paste,
echo or if you've already created the VPS with password authentication.
echo.

goto :get_vps_info

:get_vps_info
echo.
echo %CYAN%========================================%RESET%
echo %CYAN%  VPS INFORMATION%RESET%
echo %CYAN%========================================%RESET%
echo.
echo Enter your VPS details:
echo.

set /p VPS_IP=VPS IP Address: 
set /p VPS_USER=SSH Username [default: ubuntu]: 
if "%VPS_USER%"=="" set VPS_USER=%DEFAULT_USER%

:test_connection
echo.
echo %CYAN%[PHASE 3] Testing SSH Connection%RESET%
echo.
echo Testing connection to %VPS_USER%@%VPS_IP%...
echo.

ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no -o ConnectTimeout=10 %VPS_USER%@%VPS_IP% "echo CONNECTION OK" >nul 2>&1

if errorlevel 1 (
    echo %RED%[FAIL] SSH connection failed%RESET%
    echo.
    echo Troubleshooting:
    echo   1. Verify the IP address is correct
    echo   2. Check that the VPS is running
    echo   3. Ensure the SSH key was properly added to the VPS
    echo   4. For password deployment, try manual SSH first:
    echo      ssh %VPS_USER%@%VPS_IP%
    echo.
    choice /C YN /M "Retry connection?"
    if not errorlevel 2 goto :test_connection
    exit /b 1
)

echo %GREEN%[OK] SSH connection successful!%RESET%
echo.

:: ============================================================================
:: PHASE 4: OS DETECTION AND IP CONFIGURATION
:: ============================================================================

echo.
echo %CYAN%[PHASE 4] System Information%RESET%
echo.

echo Detecting OS and network configuration...
for /f "tokens=*" %%i in ('ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"'"') do set OS_NAME=%%i
for /f "tokens=*" %%i in ('ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "hostname -I | awk '{print $1}'"') do set OS_IP=%%i

echo.
echo   Operating System: %OS_NAME%
echo   IP Address: %OS_IP%
echo   SSH User: %VPS_USER%
echo.

if not "%OS_IP%"=="%VPS_IP%" (
    echo %YELLOW%[WARN] Detected IP (%OS_IP%) differs from input (%VPS_IP%)%RESET%
    echo This is normal if you're behind NAT or using a private network.
)

echo.
pause

:: ============================================================================
:: PHASE 5: CLOUDFLARE TUNNEL SETUP
:: ============================================================================

echo.
echo %CYAN%[PHASE 5] Cloudflare Tunnel Setup%RESET%
echo.

echo Before deploying, you need to set up a Cloudflare Tunnel.
echo.
echo If you haven't done this yet:
echo   1. Go to https://one.dash.cloudflare.com/
echo   2. Navigate to Networks ^> Tunnels
echo   3. Create a new tunnel
echo   4. Download the credentials JSON file
echo.

set /p CF_JSON=Path to tunnel credentials JSON file: 

if not exist "%CF_JSON%" (
    echo %RED%[FAIL] File not found: %CF_JSON%%RESET%
    pause
    exit /b 1
)

echo.
echo Uploading tunnel credentials to VPS...
scp -i "%SSH_KEY%" "%CF_JSON%" %VPS_USER%@%VPS_IP%:/tmp/tunnel-creds.json

if errorlevel 1 (
    echo %RED%[FAIL] Failed to upload credentials%RESET%
    pause
    exit /b 1
)

echo %GREEN%[OK] Tunnel credentials uploaded%RESET%

:: ============================================================================
:: PHASE 6: DEPLOYMENT
:: ============================================================================

echo.
echo %CYAN%[PHASE 6] Deployment%RESET%
echo.
echo Ready to deploy Axiom v%VERSION% to %VPS_IP%
echo.
echo This will:
echo   - Update system packages
echo   - Install Docker and dependencies
echo   - Configure Cloudflare Tunnel
echo   - Set up firewall
echo   - Deploy all services (Cockpit, Agent Zero x3, Dockge, FileBrowser)
echo.
echo %YELLOW%This process may take 10-15 minutes.%RESET%
echo.
choice /C YN /M "Proceed with deployment?"
if errorlevel 2 exit /b 0

echo.
echo %CYAN%Starting deployment...%RESET%
echo.

:: Upload modules directory
echo [1/9] Uploading deployment modules...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "mkdir -p /tmp/axiom-deploy"
scp -i "%SSH_KEY%" -r modules %VPS_USER%@%VPS_IP%:/tmp/axiom-deploy/

:: Move tunnel credentials
echo [2/9] Setting up Cloudflare credentials...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo mkdir -p /etc/cloudflared && sudo mv /tmp/tunnel-creds.json /etc/cloudflared/"

:: Run deployment modules
echo [3/9] Running system preparation...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo bash /tmp/axiom-deploy/modules/01-system-prep.sh"

echo [4/9] Installing core platform...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo bash /tmp/axiom-deploy/modules/02-core-platform.sh"

echo [5/9] Configuring Cloudflare Tunnel...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo bash /tmp/axiom-deploy/modules/03-cloudflare-tunnel.sh"

echo [6/9] Setting up firewall...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo bash /tmp/axiom-deploy/modules/04-firewall.sh"

echo [7/9] Installing Cockpit...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo bash /tmp/axiom-deploy/modules/05-cockpit.sh"

echo [8/9] Deploying Agent Zero instances...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo bash /tmp/axiom-deploy/modules/06-agent-zero.sh"

echo [9/9] Installing Dockge and FileBrowser...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo bash /tmp/axiom-deploy/modules/07-dockge.sh"
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo bash /tmp/axiom-deploy/modules/08-filebrowser.sh"

:: ============================================================================
:: PHASE 7: COMPLETION AND NEXT STEPS
:: ============================================================================

echo.
echo %GREEN%========================================%RESET%
echo %GREEN%  DEPLOYMENT COMPLETE!%RESET%
echo %GREEN%========================================%RESET%
echo.

:: Read domain from config
for /f "tokens=2 delims==" %%i in ('ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "grep AXIOM_DOMAIN /tmp/axiom-deploy/modules/00-config.sh | grep -v '#' | head -1"') do set DOMAIN=%%i
set DOMAIN=%DOMAIN:"=%

echo Your services are now accessible at:
echo.
echo   %CYAN%Cockpit%RESET% (System Admin):     https://d.%DOMAIN%
echo   %CYAN%Agent Zero%RESET% (Primary):       https://a.%DOMAIN%
echo   %CYAN%Agent Zero%RESET% (Secondary):     https://b.%DOMAIN%
echo   %CYAN%Agent Zero%RESET% (Tertiary):      https://c.%DOMAIN%
echo   %CYAN%Dockge%RESET% (Container Manager): https://e.%DOMAIN%
echo   %CYAN%FileBrowser%RESET% (File Manager): https://f.%DOMAIN%
echo.
echo %YELLOW%Important notes:%RESET%
echo   - FileBrowser default login: admin / admin ^(CHANGE THIS!^)
echo   - Dockge requires account setup on first access
echo   - All services are behind Cloudflare Tunnel ^(no direct ports open^)
echo.
echo %CYAN%Cleaning up...%RESET%
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_IP% "sudo rm -rf /tmp/axiom-deploy"
echo.
echo %GREEN%Thank you for using Axiom v%VERSION%!%RESET%
echo.
pause
exit /b 0
