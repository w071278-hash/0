<# :
@echo off
title PROJECT AXIOM v1.1.0
echo.
echo ============================================================
echo   PROJECT AXIOM v1.1.0 - LAUNCHER
echo ============================================================
echo [INIT] %DATE% %TIME%
ssh-keygen -R 15.204.238.67 >NUL 2>&1
echo [INIT] Handing off to PowerShell...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~f0"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [FAIL] PowerShell exited with code %ERRORLEVEL%
)
pause
exit /b
#>

# ============================================================================
#  PROJECT AXIOM v1.1.0 - POWERSHELL CONTROLLER
# ============================================================================
$ErrorActionPreference = "Stop"

# --- CONFIGURATION (edit these) ---
$ServerIP     = "15.204.238.67"
$User         = "ubuntu"
$KeyName      = "id_ed25519_vps_2026"
$KeyPath      = "$env:USERPROFILE\.ssh\$KeyName"
$ModulesLocal = Join-Path $PSScriptRoot "modules"

if (-not (Test-Path $ModulesLocal)) {
    Write-Host "[ERROR] Cannot find 'modules' directory at: $ModulesLocal" -ForegroundColor Red
    exit 1
}

# --- SSH ARGS BUILDER ---
$SSHBase = @(
    "-o", "StrictHostKeyChecking=no",
    "-o", "ConnectTimeout=10",
    "-o", "LogLevel=ERROR",
    "-i", $KeyPath
)

# ============================================================================
#  HELPER FUNCTIONS
# ============================================================================

function Invoke-Remote {
    param([string]$Command, [switch]$Interactive, [switch]$PassThru)
    $sshArgs = $SSHBase.Clone()
    if ($Interactive) { $sshArgs += "-t" }
    $sshArgs += "$User@$ServerIP"
    if ($Command) { $sshArgs += $Command }
    if ($Interactive) {
        & ssh @sshArgs
        return $LASTEXITCODE
    } elseif ($PassThru) {
        $output = & ssh @sshArgs 2>&1 | Out-String
        Write-Host $output
        return $output
    } else {
        & ssh @sshArgs 2>&1 | ForEach-Object { Write-Host $_ }
    }
}

function Send-File {
    param([string]$Local, [string]$Remote)
    $scpArgs = @("-o", "LogLevel=ERROR", "-o", "StrictHostKeyChecking=no", "-i", $KeyPath)
    & scp @scpArgs $Local "${User}@${ServerIP}:${Remote}" 2>&1 | Out-Null
}

function Wait-ForReboot {
    Write-Host "  [WAIT] Server is rebooting..." -ForegroundColor Cyan
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 5
        try {
            $result = & ssh @SSHBase "$User@$ServerIP" "echo READY" 2>$null
            if ($result -match "READY") {
                Write-Host "`n  [OK] Server is back." -ForegroundColor Green
                return
            }
        } catch {}
        Write-Host -NoNewline "." -ForegroundColor DarkGray
    }
    throw "Server did not return after 5 minutes."
}

function Upload-Modules {
    Write-Host "  Uploading module suite..." -ForegroundColor Gray
    Invoke-Remote "rm -rf /tmp/axiom-modules && mkdir -p /tmp/axiom-modules"
    foreach ($file in (Get-ChildItem "$ModulesLocal\*.sh")) {
        Write-Host "    -> $($file.Name)" -ForegroundColor DarkGray
        Send-File $file.FullName "/tmp/axiom-modules/$($file.Name)"
    }
    Write-Host "  [OK] All modules uploaded." -ForegroundColor Green
}

function Run-Module {
    param([string]$Module, [string]$Mode = "install")
    Write-Host "`n  [EXEC] $Module (mode: $Mode)" -ForegroundColor White
    $output = Invoke-Remote "sudo bash /tmp/axiom-modules/$Module $Mode" -PassThru
    if ($output -match "AXIOM_HEALTH_PASS") { return "PASS" }
    if ($output -match "AXIOM_HEALTH_FAIL") { return "FAIL" }
    return "UNKNOWN"
}

function Prompt-ServiceVerification {
    param([string]$Module, [string]$Label, [string[]]$URLs, [string[]]$FrontEnd)
    $mode = "install"
    while ($true) {
        $health = Run-Module -Module $Module -Mode $mode
        Write-Host ""
        if ($health -eq "PASS") {
            Write-Host "  [HEALTH] $Label - PASSED" -ForegroundColor Green
        } else {
            Write-Host "  [HEALTH] $Label - FAILED or UNKNOWN" -ForegroundColor Red
        }
        Write-Host "`n  Verify in your browser:" -ForegroundColor Cyan
        foreach ($url in $URLs) { Write-Host "    -> $url" -ForegroundColor White }
        if ($FrontEnd) {
            Write-Host "`n  What to expect:" -ForegroundColor Yellow
            foreach ($line in $FrontEnd) { Write-Host "    $line" -ForegroundColor Gray }
        }
        Write-Host ""
        Write-Host "  [A] Approve and continue" -ForegroundColor Green
        Write-Host "  [R] Reinstall (keep data)" -ForegroundColor Yellow
        Write-Host "  [W] Wipe and clean install" -ForegroundColor Red
        Write-Host "  [S] Skip" -ForegroundColor DarkGray
        $choice = Read-Host "  Choice"
        switch ($choice.ToUpper()) {
            "A" { Write-Host "  [OK] $Label approved." -ForegroundColor Green; return }
            "R" { Write-Host "  [REINSTALL]..." -ForegroundColor Yellow; $mode = "reinstall" }
            "W" {
                $confirm = Read-Host "  Type YES to wipe ALL data for $Label"
                if ($confirm -eq "YES") { $mode = "wipe" } else { Write-Host "  Cancelled." -ForegroundColor Gray }
            }
            "S" { Write-Host "  [SKIP]" -ForegroundColor DarkGray; return }
            default { Write-Host "  Enter A, R, W, or S." -ForegroundColor DarkGray }
        }
    }
}

# ============================================================================
#  BANNER
# ============================================================================
Clear-Host
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PROJECT AXIOM v1.1.0" -ForegroundColor Cyan
Write-Host "  Target: $User@$ServerIP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ============================================================================
#  PRE-FLIGHT 1: SERVER ADDRESS
# ============================================================================
Write-Host "`n[PRE-FLIGHT 1] Server Address" -ForegroundColor Yellow
Write-Host "  Current IP: $ServerIP" -ForegroundColor White
Write-Host "  Current user: $User" -ForegroundColor White
$newIP = Read-Host "  New IP (ENTER to keep current)"
if ($newIP) {
    $ServerIP = $newIP
    & ssh-keygen -R $ServerIP 2>$null | Out-Null
    Write-Host "  [OK] IP changed to $ServerIP" -ForegroundColor Green
}
$newUser = Read-Host "  New SSH user (ENTER to keep '$User')"
if ($newUser) { $User = $newUser }

# ============================================================================
#  PRE-FLIGHT 2: SSH KEY
# ============================================================================
Write-Host "`n[PRE-FLIGHT 2] SSH Key" -ForegroundColor Yellow
if (Test-Path $KeyPath) {
    Write-Host "  [OK] SSH key found: $KeyPath" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Key not found at: $KeyPath" -ForegroundColor Yellow
    $sshDir = "$env:USERPROFILE\.ssh"
    $keys = Get-ChildItem "$sshDir\id_*" -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne ".pub" }
    if ($keys.Count -gt 0) {
        Write-Host "  Found existing keys:" -ForegroundColor White
        $i = 1
        foreach ($k in $keys) {
            Write-Host "    [$i] $($k.Name) ($(([DateTime]::Now - $k.LastWriteTime).Days) days old)" -ForegroundColor Gray
            $i++
        }
        Write-Host "    [N] Generate new key" -ForegroundColor Gray
        $pick = Read-Host "  Pick key number or N"
        if ($pick -ne "N" -and $pick -match '^\d+$') {
            $idx = [int]$pick - 1
            if ($idx -ge 0 -and $idx -lt $keys.Count) {
                $KeyPath = $keys[$idx].FullName
                Write-Host "  [OK] Using: $KeyPath" -ForegroundColor Green
                $SSHBase = @("-o","StrictHostKeyChecking=no","-o","ConnectTimeout=10","-o","LogLevel=ERROR","-i",$KeyPath)
            }
        } else {
            & ssh-keygen -t ed25519 -f $KeyPath -N '""' -C "axiom-deploy"
            Write-Host "  [OK] Key generated at $KeyPath" -ForegroundColor Green
        }
    } else {
        & ssh-keygen -t ed25519 -f $KeyPath -N '""' -C "axiom-deploy"
        Write-Host "  [OK] Key generated at $KeyPath" -ForegroundColor Green
    }
    if (Test-Path "$KeyPath.pub") {
        $pubKey = Get-Content "$KeyPath.pub"
        Write-Host "`n  PUBLIC KEY (paste into VPS provider):" -ForegroundColor Cyan
        Write-Host "  $pubKey" -ForegroundColor White
        $pubKey | Set-Clipboard
        Write-Host "  (Copied to clipboard)" -ForegroundColor Green
        Read-Host "`n  Press ENTER after the key is on your server"
    }
}

# ============================================================================
#  PRE-FLIGHT 3: CONNECTION TEST
# ============================================================================
Write-Host "`n[PRE-FLIGHT 3] SSH Connection Test" -ForegroundColor Yellow
$connected = $false
for ($attempt = 1; $attempt -le 3; $attempt++) {
    Write-Host "  Testing $User@$ServerIP (attempt $attempt)..." -ForegroundColor White
    $testResult = & ssh @SSHBase "$User@$ServerIP" "echo AXIOM_SSH_OK" 2>&1 | Out-String
    if ($testResult -match "AXIOM_SSH_OK") {
        Write-Host "  [OK] Connected!" -ForegroundColor Green
        $connected = $true
        break
    }
    Write-Host "  [FAIL] Connection failed." -ForegroundColor Red
    if ($attempt -lt 3) {
        $retry = Read-Host "  Retry? (Y/N)"
        if ($retry -ne "Y") { break }
    }
}
if (-not $connected) {
    Write-Host "  Cannot connect to server. Aborting." -ForegroundColor Red
    exit 1
}

# ============================================================================
#  PRE-FLIGHT 4: OS DETECTION
# ============================================================================
Write-Host "`n[PRE-FLIGHT 4] OS Detection" -ForegroundColor Yellow
$osInfo = Invoke-Remote 'cat /etc/os-release 2>/dev/null | grep -E "^(PRETTY_NAME|ID|VERSION_ID)=" ; uname -rm' -PassThru
Write-Host "  $osInfo" -ForegroundColor Gray

# ============================================================================
#  PRE-FLIGHT 5: SNAPSHOT REMINDER
# ============================================================================
Write-Host "`n[PRE-FLIGHT 5] Snapshot Reminder" -ForegroundColor Yellow
Write-Host "  Consider taking a VPS snapshot before deploying." -ForegroundColor White
Write-Host "  OVH: Control Panel -> VPS -> Snapshot -> Create" -ForegroundColor Gray
Read-Host "`n  Press ENTER to begin deployment (Ctrl+C to abort)"

# ============================================================================
#  STAGE 1: SYSTEM PREPARATION
# ============================================================================
Write-Host "`n[STAGE 1] System Preparation" -ForegroundColor Yellow
Upload-Modules
$output = Invoke-Remote "sudo bash /tmp/axiom-modules/01-system-prep.sh" -PassThru
if ($output -match "AXIOM_REBOOT_REQUIRED") {
    Wait-ForReboot
    Upload-Modules
} else {
    Write-Host "  [OK] No reboot needed." -ForegroundColor Green
}

# ============================================================================
#  STAGE 2: CORE PLATFORM
# ============================================================================
Write-Host "`n[STAGE 2] Core Platform" -ForegroundColor Yellow
Invoke-Remote "sudo bash /tmp/axiom-modules/02-core-platform.sh"
Write-Host "  [OK] Docker and packages installed." -ForegroundColor Green

# ============================================================================
#  STAGE 3: CLOUDFLARE TUNNEL
# ============================================================================
Write-Host "`n[STAGE 3] Cloudflare Tunnel" -ForegroundColor Yellow
Invoke-Remote "sudo bash /tmp/axiom-modules/03-cloudflare-tunnel.sh"
Write-Host "`n  MANUAL STEP: Cloudflare Authentication" -ForegroundColor Yellow
Write-Host "  A URL will appear. Copy it, open in browser, authorize." -ForegroundColor White
Read-Host "  Press ENTER to start authentication"
Invoke-Remote "cloudflared tunnel login" -Interactive
Write-Host "  Finalizing tunnel..." -ForegroundColor Green
$tunnelOut = Invoke-Remote "sudo bash /opt/axiom-finalize-tunnel.sh" -PassThru
if ($tunnelOut -match "AXIOM_TUNNEL_HEALTHY") {
    Write-Host "  [OK] Tunnel is live." -ForegroundColor Green
} else {
    Write-Host "  [WARN] Tunnel may have issues." -ForegroundColor Yellow
}

# ============================================================================
#  STAGE 4: FIREWALL
# ============================================================================
Write-Host "`n[STAGE 4] Firewall" -ForegroundColor Yellow
Invoke-Remote "sudo bash /tmp/axiom-modules/04-firewall.sh"
Write-Host "  [OK] Firewall active. Only SSH (22) exposed." -ForegroundColor Green

# ============================================================================
#  STAGE 5: SERVICE DEPLOYMENT
# ============================================================================
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  STEPPED SERVICE DEPLOYMENT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Get domain from config
$domain = (Invoke-Remote 'source /tmp/axiom-modules/00-config.sh && echo $AXIOM_DOMAIN' -PassThru).Trim()

Prompt-ServiceVerification `
    -Module "05-cockpit.sh" `
    -Label "Cockpit" `
    -URLs @("https://d.$domain") `
    -FrontEnd @(
        "System admin panel - login with your server SSH credentials",
        "Browser may warn about self-signed certificate (click Advanced > Proceed)",
        "This is the first proof-of-life through the tunnel"
    )

Prompt-ServiceVerification `
    -Module "06-agent-zero.sh" `
    -Label "Agent Zero Triad" `
    -URLs @("https://a.$domain","https://b.$domain","https://c.$domain") `
    -FrontEnd @(
        "AI agent chat interface",
        "Password is set in modules/00-config.sh (default: AxiomSecureRFC2026!)",
        "Three independent instances for redundancy"
    )

Prompt-ServiceVerification `
    -Module "07-dockge.sh" `
    -Label "Dockge" `
    -URLs @("https://e.$domain") `
    -FrontEnd @(
        "Docker container management dashboard",
        "First visit will prompt you to create an admin account",
        "Use this to manage containers and view logs"
    )

Prompt-ServiceVerification `
    -Module "08-filebrowser.sh" `
    -Label "FileBrowser" `
    -URLs @("https://f.$domain") `
    -FrontEnd @(
        "Web file explorer with full filesystem access",
        "DEFAULT LOGIN: admin / admin - CHANGE THIS IMMEDIATELY",
        "Browse to /opt/stacks for Docker compose files"
    )

# ============================================================================
#  DEPLOYMENT COMPLETE
# ============================================================================
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  AXIOM v1.1.0 DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  LIVE SERVICES:" -ForegroundColor White
Write-Host "    a.$domain  Agent Zero Core" -ForegroundColor Gray
Write-Host "    b.$domain  Agent Zero Alt 1" -ForegroundColor Gray
Write-Host "    c.$domain  Agent Zero Alt 2" -ForegroundColor Gray
Write-Host "    d.$domain  Cockpit" -ForegroundColor Gray
Write-Host "    e.$domain  Dockge" -ForegroundColor Gray
Write-Host "    f.$domain  FileBrowser" -ForegroundColor Gray
Write-Host ""
Write-Host "  SECURITY:" -ForegroundColor White
Write-Host "    Firewall: only SSH (22) exposed" -ForegroundColor Gray
Write-Host "    All services via Cloudflare tunnel" -ForegroundColor Gray
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor White
Write-Host "    - Change default passwords (FileBrowser, Cockpit)" -ForegroundColor Gray
Write-Host "    - Consider Cloudflare Access for extra auth" -ForegroundColor Gray
Write-Host "    - g-z.$domain available for future services" -ForegroundColor Gray
Write-Host ""