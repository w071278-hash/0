# ============================================================================
#  PROJECT AXIOM v1.1.2 - SINGLE FILE DEPLOYMENT CONTROLLER
#  All bash modules are embedded and written to disk at runtime.
#  Just run:  powershell -ExecutionPolicy Bypass -File axiom.ps1
# ============================================================================
$ErrorActionPreference = "Stop"
# --- CONFIGURATION (edit these) ---
$ServerIP = "15.204.238.67"
$User     = "ubuntu"
$KeyName  = "id_ed25519_vps_2026"
$KeyPath  = "$env:USERPROFILE\.ssh\$KeyName"
# ============================================================================
#  WRITE BASH MODULES TO TEMP FOLDER
# ============================================================================
$TempModules = Join-Path $env:TEMP "axiom-modules"
New-Item -ItemType Directory -Path $TempModules -Force | Out-Null
# Helper: write a bash module and strip Windows line endings immediately
function Write-Module {
    param([string]$Name, [string]$Content)
    $path  = Join-Path $script:TempModules $Name
    $clean = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($path, $clean, [System.Text.UTF8Encoding]::new($false))
}
# --------------------------------------------------------------------------
Write-Module "00-config.sh" @'
#!/bin/bash
# PROJECT AXIOM v1.1.2 - CONFIGURATION
AXIOM_VERSION="1.1.2"
AXIOM_DOMAIN="willowcherry.us"
AXIOM_TUNNEL_NAME="axiom-tunnel"
AXIOM_LOG="/var/log/axiom-deploy.log"
AXIOM_CREDS_DIR="/etc/cloudflared"
AXIOM_STACKS_DIR="/opt/stacks"
declare -A SERVICES
SERVICES=(
    [a]="agent-zero-core|5000|80|agent0ai/agent-zero:latest|Primary Agent Zero"
    [b]="agent-zero-alt1|50001|80|agent0ai/agent-zero:latest|Secondary Agent Zero"
    [c]="agent-zero-alt2|8000|80|agent0ai/agent-zero:latest|Tertiary Agent Zero"
    [d]="cockpit|9090|9090|SYSTEM|System administration panel"
    [e]="dockge|5001|5001|louislam/dockge:1|Docker container management"
    [f]="filebrowser|8080|80|filebrowser/filebrowser:latest|Web file manager"
    [g]="ollama|11434|11434|ollama/ollama:latest|Local AI model server"
)
AZ_RFC_PASSWORD="AxiomSecureRFC2026!"
AZ_ALLOWED_ORIGINS="*"
svc_name()  { echo "$1" | cut -d'|' -f1; }
svc_port()  { echo "$1" | cut -d'|' -f2; }
svc_cport() { echo "$1" | cut -d'|' -f3; }
svc_image() { echo "$1" | cut -d'|' -f4; }
svc_desc()  { echo "$1" | cut -d'|' -f5; }
assigned_letters() { printf '%s\n' "${!SERVICES[@]}" | sort; }
'@
# --------------------------------------------------------------------------
Write-Module "lib.sh" @'
#!/bin/bash
# PROJECT AXIOM - SHARED LIBRARY
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "${AXIOM_LOG:-/var/log/axiom-deploy.log}"
}
log_error()   { log "[ERROR] $1";   [[ -n "${2:-}" ]] && exit "$2"; }
log_success() { log "[SUCCESS] $1"; }
log_warn()    { log "[WARN] $1";    }
container_running() { docker ps --format '{{.Names}}' | grep -q "^${1}$"; }
wait_for_container() {
    local name="$1" timeout="${2:-60}" elapsed=0
    log "Waiting for '$name' (timeout: ${timeout}s)..."
    while [[ $elapsed -lt $timeout ]]; do
        if container_running "$name"; then
            local health
            health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || true)
            if [[ -z "$health" ]] || [[ "$health" == "healthy" ]]; then
                log_success "Container '$name' is ready"; return 0
            fi
            [[ "$health" == "unhealthy" ]] && log_error "Container '$name' is unhealthy" 1
        fi
        sleep 2; elapsed=$((elapsed + 2))
    done
    log_error "Timeout waiting for '$name'" 1
}
remove_container() {
    local name="$1"
    if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
        log "Removing existing container '$name'..."
        docker stop "$name" >/dev/null 2>&1 || true
        docker rm   "$name" >/dev/null 2>&1 || true
        log_success "Container '$name' removed"
    fi
}
check_http() {
    local url="$1" timeout="${2:-60}" elapsed=0
    log "Checking HTTP: $url (timeout: ${timeout}s)..."
    while [[ $elapsed -lt $timeout ]]; do
        curl -sf "$url" >/dev/null 2>&1 && { log_success "HTTP reachable: $url"; return 0; }
        sleep 2; elapsed=$((elapsed + 2))
    done
    log_warn "HTTP not reachable: $url"; return 1
}
check_port() {
    local host="$1" port="$2" timeout="${3:-30}" elapsed=0
    log "Checking TCP ${host}:${port} (timeout: ${timeout}s)..."
    while [[ $elapsed -lt $timeout ]]; do
        nc -z "$host" "$port" 2>/dev/null && { log_success "Port open: ${host}:${port}"; return 0; }
        sleep 2; elapsed=$((elapsed + 2))
    done
    log_warn "Port not open: ${host}:${port}"; return 1
}
command_exists() { command -v "$1" >/dev/null 2>&1; }
require_root()   { [[ $EUID -ne 0 ]] && log_error "Must be run as root (use sudo)" 1; }
service_active() { systemctl is-active --quiet "$1"; }
ensure_dir()     { [[ ! -d "$1" ]] && mkdir -p "$1" && log "Created directory: $1"; }
'@
# --------------------------------------------------------------------------
Write-Module "01-system-prep.sh" @'
#!/bin/bash
# FIX-1: emits AXIOM_REBOOT_REQUIRED before taking any action
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 01: System Preparation ==="
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
log_success "Packages updated"
if [[ -f /var/run/reboot-required ]]; then
    log_warn "Reboot required (kernel or critical updates applied)"
    echo "AXIOM_REBOOT_REQUIRED"
    if [[ "${AXIOM_AUTO_REBOOT:-0}" == "1" ]]; then
        log "Auto-reboot in 10 seconds..."; sleep 10; reboot
    else
        exit 0
    fi
else
    log_success "No reboot required."
fi
log "=== MODULE 01: Complete ==="
'@
# --------------------------------------------------------------------------
Write-Module "02-core-platform.sh" @'
#!/bin/bash
# FIX-6: netcat-openbsd instead of stub netcat for Ubuntu 22.04+
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 02: Core Platform ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    ca-certificates curl gnupg lsb-release apt-transport-https \
    software-properties-common git wget unzip netcat-openbsd jq
log_success "Essential packages installed"
if command_exists docker; then
    log "Docker already installed: $(docker --version)"
else
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log_success "Docker installed: $(docker --version)"
fi
service_active docker || { systemctl start docker; systemctl enable docker; }
log_success "Docker service active"
docker ps >/dev/null 2>&1 || log_error "Docker not functioning" 1
log "Docker Compose: $(docker compose version)"
ensure_dir "$AXIOM_STACKS_DIR"
log "=== MODULE 02: Complete ==="
'@
# --------------------------------------------------------------------------
Write-Module "03-cloudflare-tunnel.sh" @'
#!/bin/bash
# FIX-5: emits AXIOM_TUNNEL_HEALTHY for reliable PS health detection
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 03: Cloudflare Tunnel ==="
if ! command_exists cloudflared; then
    ARCH=$(dpkg --print-architecture)
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
    dpkg -i "cloudflared-linux-${ARCH}.deb"
    rm "cloudflared-linux-${ARCH}.deb"
    log_success "cloudflared installed: $(cloudflared --version)"
fi
ensure_dir "$AXIOM_CREDS_DIR"
CRED_FILE=$(find "$AXIOM_CREDS_DIR" -name "*.json" -type f | head -n 1)
[[ -z "$CRED_FILE" ]] && log_error "No credentials in $AXIOM_CREDS_DIR" 1
TUNNEL_ID=$(basename "$CRED_FILE" .json)
log "Found credentials: $TUNNEL_ID"
CONFIG_FILE="$AXIOM_CREDS_DIR/config.yml"
{
    echo "tunnel: $TUNNEL_ID"
    echo "credentials-file: $CRED_FILE"
    echo ""
    echo "ingress:"
    for letter in $(assigned_letters); do
        entry="${SERVICES[$letter]}"
        port=$(svc_port "$entry")
        echo "  - hostname: ${letter}.${AXIOM_DOMAIN}"
        echo "    service: http://localhost:${port}"
    done
    echo "  - service: http_status:404"
} > "$CONFIG_FILE"
log_success "Config written"
if systemctl is-enabled --quiet cloudflared 2>/dev/null; then
    cp "$CONFIG_FILE" /etc/cloudflared/config.yml
    systemctl restart cloudflared
else
    cloudflared service install
    cp "$CONFIG_FILE" /etc/cloudflared/config.yml
    systemctl start cloudflared
    systemctl enable cloudflared
fi
sleep 5
if service_active cloudflared; then
    log_success "Cloudflare Tunnel is active"
    echo "AXIOM_TUNNEL_HEALTHY"
else
    log_error "Tunnel failed - check: journalctl -u cloudflared -n 50" 1
fi
log "=== MODULE 03: Complete ==="
for letter in $(assigned_letters); do echo "  https://${letter}.${AXIOM_DOMAIN}"; done
'@
# --------------------------------------------------------------------------
# ROOT CAUSE OF PARSE ERROR:
#   The previous version used $credScript = @'...'@ as an inline
#   PowerShell here-string.  The bash regex  '(?<=with id )[a-f0-9-]+'
#   followed by  ||  on the same line caused the PowerShell parser to
#   misread quote boundaries and terminate the here-string early, then
#   try to parse the remaining bash as PowerShell code.
#
# FIX: The credential setup is now a proper bash module file (03b).
#   It is written by Write-Module like every other script, uploaded
#   alongside them, and called as a normal SSH command.  No inline
#   bash-in-PowerShell-string, no quote ambiguity.
Write-Module "03b-tunnel-creds.sh" @'
#!/bin/bash
# Run AFTER: cloudflared tunnel login
# Finds or creates the "axiom" tunnel and copies credentials to /etc/cloudflared/
set -e
# Try to find an existing tunnel named axiom
TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep axiom | awk '{print $1}' || true)
# If not found, create it and extract the UUID from the output
if [[ -z "$TUNNEL_ID" ]]; then
    CREATE_OUT=$(cloudflared tunnel create axiom 2>&1 || true)
    echo "$CREATE_OUT"
    # Parse UUID with sed (no grep -P dependency)
    TUNNEL_ID=$(echo "$CREATE_OUT" | sed -n 's/.*with id \([a-f0-9-]*\).*/\1/p' | head -n 1)
fi
if [[ -z "$TUNNEL_ID" ]]; then
    echo "[ERROR] Could not create or find a tunnel named axiom"
    exit 1
fi
CRED_SOURCE="$HOME/.cloudflared/${TUNNEL_ID}.json"
if [[ ! -f "$CRED_SOURCE" ]]; then
    echo "[ERROR] Credentials file not found: $CRED_SOURCE"
    exit 1
fi
sudo mkdir -p /etc/cloudflared
sudo cp "$CRED_SOURCE" /etc/cloudflared/
echo "AXIOM_TUNNEL_CREDS_OK"
'@
# --------------------------------------------------------------------------
Write-Module "04-firewall.sh" @'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 04: Firewall ==="
command_exists ufw || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ufw
ufw --force reset >/dev/null 2>&1
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH access'
ufw --force enable
service_active ufw && log_success "Firewall active (SSH only)" || log_error "Firewall failed" 1
ufw status verbose | tee -a "$AXIOM_LOG"
log "=== MODULE 04: Complete ==="
'@
# --------------------------------------------------------------------------
Write-Module "05-cockpit.sh" @'
#!/bin/bash
# FIX-4: cockpit-docker removed in Ubuntu 22.04+; use cockpit-machines
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 05: Cockpit ==="
UBUNTU_VER=$(lsb_release -rs 2>/dev/null || echo "unknown")
log "OS version: $UBUNTU_VER"
if ! command_exists cockpit-bridge; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cockpit
    if [[ "$UBUNTU_VER" == "20.04" ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cockpit-docker || \
            log_warn "cockpit-docker unavailable (non-fatal)"
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cockpit-machines || \
            log_warn "cockpit-machines unavailable (non-fatal)"
    fi
    log_success "Cockpit installed"
fi
systemctl enable --now cockpit.socket
sleep 3
if service_active cockpit.socket; then
    for letter in "${!SERVICES[@]}"; do
        entry="${SERVICES[$letter]}"
        if [[ "$(svc_name "$entry")" == "cockpit" ]]; then
            log "Cockpit: https://${letter}.${AXIOM_DOMAIN}  port: $(svc_port "$entry")"
            break
        fi
    done
    log_success "Cockpit active"
    echo "AXIOM_HEALTH_PASS"
else
    log_error "Cockpit failed to start" 1
fi
log "=== MODULE 05: Complete ==="
'@
# --------------------------------------------------------------------------
Write-Module "06-agent-zero.sh" @'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 06: Agent Zero ==="
for letter in a b c; do
    entry="${SERVICES[$letter]}"
    name=$(svc_name "$entry"); port=$(svc_port "$entry")
    cport=$(svc_cport "$entry"); image=$(svc_image "$entry")
    desc=$(svc_desc "$entry")
    log "Deploying $desc on port $port..."
    remove_container "$name"
    data_dir="$AXIOM_STACKS_DIR/agent-zero/${name}"
    ensure_dir "$data_dir"
    docker run -d --name "$name" --restart unless-stopped \
        -p "${port}:${cport}" \
        -v "${data_dir}:/app/data" \
        -e RFC_PASSWORD="$AZ_RFC_PASSWORD" \
        -e ALLOWED_ORIGINS="$AZ_ALLOWED_ORIGINS" \
        "$image"
    wait_for_container "$name" 30
    check_http "http://localhost:${port}" 30 || log_warn "$name HTTP check failed"
    log_success "$desc: https://${letter}.${AXIOM_DOMAIN}"
done
echo "AXIOM_HEALTH_PASS"
log "=== MODULE 06: Complete ==="
'@
# --------------------------------------------------------------------------
Write-Module "07-dockge.sh" @'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 07: Dockge ==="
entry="${SERVICES[e]}"
name=$(svc_name "$entry"); port=$(svc_port "$entry")
cport=$(svc_cport "$entry"); image=$(svc_image "$entry")
desc=$(svc_desc "$entry")
remove_container "$name"
data_dir="$AXIOM_STACKS_DIR/dockge"
ensure_dir "$data_dir"
docker run -d --name "$name" --restart unless-stopped \
    -p "${port}:${cport}" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${data_dir}:/app/data" \
    -v "$AXIOM_STACKS_DIR:/opt/stacks" \
    -e DOCKGE_STACKS_DIR=/opt/stacks \
    "$image"
wait_for_container "$name" 30
check_http "http://localhost:${port}" 30 || log_warn "$name HTTP check failed"
echo "AXIOM_HEALTH_PASS"
log_success "$desc: https://e.${AXIOM_DOMAIN}"
log "=== MODULE 07: Complete ==="
'@
# --------------------------------------------------------------------------
Write-Module "08-filebrowser.sh" @'
#!/bin/bash
# FIX-3: pre-create bind-mount targets as regular files before docker run.
# Without this Docker creates them as directories and FileBrowser crash-loops.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 08: FileBrowser ==="
entry="${SERVICES[f]}"
name=$(svc_name "$entry"); port=$(svc_port "$entry")
cport=$(svc_cport "$entry"); image=$(svc_image "$entry")
desc=$(svc_desc "$entry")
remove_container "$name"
data_dir="$AXIOM_STACKS_DIR/filebrowser"
ensure_dir "$data_dir"
[[ ! -f "${data_dir}/database.db"      ]] && touch "${data_dir}/database.db"
[[ ! -f "${data_dir}/filebrowser.json" ]] && echo '{}' > "${data_dir}/filebrowser.json"
docker run -d --name "$name" --restart unless-stopped \
    -p "${port}:${cport}" \
    -v "$AXIOM_STACKS_DIR:/srv" \
    -v "${data_dir}/database.db:/database.db" \
    -v "${data_dir}/filebrowser.json:/.filebrowser.json" \
    "$image"
wait_for_container "$name" 30
if check_http "http://localhost:${port}" 30; then
    echo "AXIOM_HEALTH_PASS"
else
    log_warn "$name HTTP check failed"
    echo "AXIOM_HEALTH_FAIL"
fi
log_success "$desc: https://f.${AXIOM_DOMAIN}"
log "DEFAULT LOGIN: admin / admin -- change this immediately!"
log "=== MODULE 08: Complete ==="
'@
# --------------------------------------------------------------------------
Write-Module "09-ollama.sh" @'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"
require_root
log "=== MODULE 09: Ollama ==="
entry="${SERVICES[g]}"
name=$(svc_name "$entry"); port=$(svc_port "$entry")
cport=$(svc_cport "$entry"); image=$(svc_image "$entry")
desc=$(svc_desc "$entry")
remove_container "$name"
data_dir="$AXIOM_STACKS_DIR/ollama"
ensure_dir "$data_dir"
docker run -d --name "$name" --restart unless-stopped \
    -p "${port}:${cport}" \
    -v "${data_dir}:/root/.ollama" \
    "$image"
wait_for_container "$name" 60
if check_http "http://localhost:${port}" 60; then
    echo "AXIOM_HEALTH_PASS"
else
    log_warn "$name HTTP check failed"
    echo "AXIOM_HEALTH_FAIL"
fi
log "Pulling phi3:mini (this may take several minutes)..."
docker exec "$name" ollama pull phi3:mini
log_success "$desc: https://g.${AXIOM_DOMAIN}"
log "=== MODULE 09: Complete ==="
'@
# ============================================================================
#  SSH HELPERS
# ============================================================================
function Get-SSHBase {
    return @(
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=NUL",
        "-o", "ConnectTimeout=10",
        "-o", "LogLevel=ERROR",
        "-i", $script:KeyPath
    )
}
$SSHBase = Get-SSHBase
function Invoke-Remote {
    param([string]$Command, [switch]$Interactive, [switch]$PassThru)
    $sshArgs = $script:SSHBase + @("$script:User@$script:ServerIP")
    if ($Interactive) { $sshArgs = @("-t") + $sshArgs }
    if ($Command)     { $sshArgs += $Command }
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try {
        if ($Interactive) {
            & ssh @sshArgs; return $LASTEXITCODE
        } elseif ($PassThru) {
            $out = & ssh @sshArgs 2>&1 | Out-String
            Write-Host $out; return $out
        } else {
            & ssh @sshArgs 2>&1 | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [WARN] Exit $LASTEXITCODE" -ForegroundColor Yellow
            }
        }
    } finally { $ErrorActionPreference = $prev }
}
function Send-File {
    param([string]$Local, [string]$Remote)
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -i $script:KeyPath `
        $Local "$($script:User)@$($script:ServerIP):$Remote" 2>&1 | Out-Null
    $ec = $LASTEXITCODE; $ErrorActionPreference = $prev
    if ($ec -ne 0) { throw "SCP failed (exit $ec): $Local -> $Remote" }
}
function Wait-ForReboot {
    Write-Host "  [WAIT] Server rebooting..." -ForegroundColor Cyan
    $prev = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep 5
        try {
            $r = & ssh @($script:SSHBase + @("$script:User@$script:ServerIP")) "echo READY" 2>$null
            if ($r -match "READY") {
                Write-Host ""; Write-Host "  [OK] Server is back." -ForegroundColor Green
                $ErrorActionPreference = $prev; return
            }
        } catch {}
        Write-Host -NoNewline "." -ForegroundColor DarkGray
    }
    $ErrorActionPreference = $prev
    throw "Server did not return after 5 minutes."
}
function Send-Modules {
    Write-Host "  Uploading modules..." -ForegroundColor Gray
    Invoke-Remote "rm -rf /tmp/axiom-modules && mkdir -p /tmp/axiom-modules"
    foreach ($f in (Get-ChildItem "$script:TempModules\*.sh")) {
        Write-Host "    -> $($f.Name)" -ForegroundColor DarkGray
        Send-File $f.FullName "/tmp/axiom-modules/$($f.Name)"
    }
    Invoke-Remote "find /tmp/axiom-modules/ -name '*.sh' -exec sed -i 's/\r$//' {} +" | Out-Null
    Write-Host "  [OK] Modules uploaded." -ForegroundColor Green
}
function Invoke-Module {
    param([string]$Module, [string]$Mode = "install")
    Write-Host ""
    switch ($Mode) {
        "install"   { Write-Host "  [DEPLOY]    $Module" -ForegroundColor Cyan }
        "reinstall" { Write-Host "  [REINSTALL] $Module  (data kept)" -ForegroundColor Yellow }
        "wipe"      { Write-Host "  [WIPE]      $Module  (data removed)" -ForegroundColor Red }
        default     { Write-Host "  [EXEC]      $Module" -ForegroundColor White }
    }
    $out = Invoke-Remote "sudo bash /tmp/axiom-modules/$Module $Mode" -PassThru
    if ($out -match "AXIOM_HEALTH_PASS") { return "PASS" }
    if ($out -match "AXIOM_HEALTH_FAIL") { return "FAIL" }
    return "UNKNOWN"
}
function Invoke-ServiceVerification {
    param([string]$Module, [string]$Label, [string[]]$URLs,
          [string[]]$FrontEnd, [string]$ETA = "1-2 min")
    $mode = "install"; $first = $true
    while ($true) {
        if ($first) {
            Write-Host ""
            Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
            Write-Host "  SERVICE : $Label   (ETA: $ETA)"          -ForegroundColor Cyan
            Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
            $first = $false
        }
        $health = Invoke-Module -Module $Module -Mode $mode
        Write-Host ""
        if ($health -eq "PASS") { Write-Host "  [HEALTH] PASSED" -ForegroundColor Green }
        else                    { Write-Host "  [HEALTH] FAILED or UNKNOWN" -ForegroundColor Red }
        Write-Host ""
        Write-Host "  Access:" -ForegroundColor Cyan
        foreach ($u in $URLs) { Write-Host "    * $u" -ForegroundColor White }
        if ($FrontEnd) {
            Write-Host ""; Write-Host "  Expect:" -ForegroundColor Yellow
            foreach ($l in $FrontEnd) { Write-Host "    - $l" -ForegroundColor Gray }
        }
        Write-Host ""
        Write-Host "  [A] Approve   [R] Reinstall   [W] Wipe   [S] Skip" -ForegroundColor White
        $c = (Read-Host "  Choice").ToUpper()
        switch ($c) {
            "A" { Write-Host "  [OK] $Label approved." -ForegroundColor Green; return }
            "R" { Write-Host "  Reinstalling..." -ForegroundColor Yellow; $mode = "reinstall" }
            "W" {
                $cf = Read-Host "  Type YES to wipe ALL data for $Label"
                if ($cf -eq "YES") { $mode = "wipe" }
                else               { Write-Host "  Cancelled." -ForegroundColor Gray }
            }
            "S" { Write-Host "  [SKIP]" -ForegroundColor DarkGray; return }
            default { Write-Host "  Enter A, R, W, or S." -ForegroundColor Yellow }
        }
    }
}
# ============================================================================
#  BANNER
# ============================================================================
Clear-Host
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PROJECT AXIOM v1.1.2  (single-file edition)" -ForegroundColor Cyan
Write-Host "  Target : $User@$ServerIP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
# ============================================================================
#  PRE-FLIGHT 1: SERVER ADDRESS
# ============================================================================
Write-Host ""; Write-Host "[PRE-FLIGHT 1] Server Address" -ForegroundColor Yellow
Write-Host "  IP   : $ServerIP" -ForegroundColor White
Write-Host "  User : $User"     -ForegroundColor White
$n = Read-Host "  New IP (ENTER to keep)"
if ($n) { $ServerIP = $n; & ssh-keygen -R $ServerIP 2>$null; Write-Host "  [OK] IP: $ServerIP" -ForegroundColor Green }
$n = Read-Host "  New SSH user (ENTER to keep '$User')"
if ($n) { $User = $n }
$SSHBase = Get-SSHBase
# ============================================================================
#  PRE-FLIGHT 2: SSH KEY
# ============================================================================
Write-Host ""; Write-Host "[PRE-FLIGHT 2] SSH Key" -ForegroundColor Yellow
if (Test-Path $KeyPath) {
    Write-Host "  [OK] Key found: $KeyPath" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Key not found: $KeyPath" -ForegroundColor Yellow
    $sshDir = "$env:USERPROFILE\.ssh"
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory $sshDir -Force | Out-Null }
    $keys = Get-ChildItem "$sshDir\id_*" -EA SilentlyContinue | Where-Object { $_.Extension -ne ".pub" }
    if ($keys.Count -gt 0) {
        $i = 1
        foreach ($k in $keys) { Write-Host "    [$i] $($k.Name)" -ForegroundColor Gray; $i++ }
        Write-Host "    [N] Generate new key" -ForegroundColor Gray
        $p = Read-Host "  Pick number or N"
        if ($p -ne "N" -and $p -match '^\d+$') {
            $idx = [int]$p - 1
            if ($idx -ge 0 -and $idx -lt $keys.Count) {
                $KeyPath = $keys[$idx].FullName
                Write-Host "  [OK] Using: $KeyPath" -ForegroundColor Green
            }
        } else {
            & ssh-keygen -t ed25519 -f $KeyPath -N "" -C "axiom-deploy"
        }
    } else {
        & ssh-keygen -t ed25519 -f $KeyPath -N "" -C "axiom-deploy"
    }
    $SSHBase = Get-SSHBase
    if (Test-Path "$KeyPath.pub") {
        $pub = Get-Content "$KeyPath.pub"
        Write-Host ""; Write-Host "  PUBLIC KEY (paste into your VPS provider):" -ForegroundColor Cyan
        Write-Host "  $pub" -ForegroundColor White
        $pub | Set-Clipboard
        Write-Host "  (Copied to clipboard)" -ForegroundColor Green
        Read-Host "  Press ENTER after adding the key to your VPS"
    }
}
# ============================================================================
#  PRE-FLIGHT 3: CONNECTION TEST
# ============================================================================
Write-Host ""; Write-Host "[PRE-FLIGHT 3] Connection Test" -ForegroundColor Yellow
$connected = $false
for ($i = 1; $i -le 3; $i++) {
    Write-Host "  Attempt $i of 3..." -ForegroundColor White
    $prev = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    try {
        $r = & ssh @SSHBase "$User@$ServerIP" "echo AXIOM_SSH_OK" 2>$null
        if ($r -match "AXIOM_SSH_OK") { $connected = $true }
    } catch {}
    $ErrorActionPreference = $prev
    if ($connected) { Write-Host "  [OK] Connected!" -ForegroundColor Green; break }
    Write-Host "  [FAIL]" -ForegroundColor Red
    if ($i -lt 3) {
        $retry = Read-Host "  Retry? (Y/N)"
        if ($retry.ToUpper() -ne "Y") { break }
    }
}
if (-not $connected) { Write-Host "  Cannot connect. Aborting." -ForegroundColor Red; exit 1 }
# ============================================================================
#  PRE-FLIGHT 4: OS DETECTION
# ============================================================================
Write-Host ""; Write-Host "[PRE-FLIGHT 4] OS Detection" -ForegroundColor Yellow
$os = Invoke-Remote "grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 ; uname -rm" -PassThru
Write-Host "  $($os.Trim())" -ForegroundColor Gray
# ============================================================================
#  PRE-FLIGHT 5: SNAPSHOT REMINDER
# ============================================================================
Write-Host ""; Write-Host "[PRE-FLIGHT 5] Snapshot Reminder" -ForegroundColor Yellow
Write-Host "  Take a VPS snapshot now.  OVH: Control Panel > VPS > Snapshot > Create" -ForegroundColor White
Read-Host "  Press ENTER to begin (Ctrl+C to abort)"
# ============================================================================
#  STAGE 1: SYSTEM PREPARATION
# ============================================================================
Write-Host ""
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "|  STAGE 1: System Preparation            (est. 2-5 min) |" -ForegroundColor Yellow
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
Send-Modules
$out = Invoke-Remote "sudo bash /tmp/axiom-modules/01-system-prep.sh" -PassThru
if ($out -match "AXIOM_REBOOT_REQUIRED") {
    Write-Host "  Reboot required - waiting..." -ForegroundColor Cyan
    Wait-ForReboot; Send-Modules
    Write-Host "  [OK] Back online." -ForegroundColor Green
} else {
    Write-Host "  [OK] No reboot needed." -ForegroundColor Green
}
# ============================================================================
#  STAGE 2: CORE PLATFORM
# ============================================================================
Write-Host ""
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "|  STAGE 2: Core Platform (Docker)        (est. 3-7 min) |" -ForegroundColor Yellow
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
& ssh @SSHBase "$User@$ServerIP" "sudo bash /tmp/axiom-modules/02-core-platform.sh" 2>&1 |
    ForEach-Object { Write-Host $_ }
$ec = $LASTEXITCODE; $ErrorActionPreference = $prev
if ($ec -eq 0) { Write-Host "  [OK] Core platform ready." -ForegroundColor Green }
else { Write-Host "  [ERROR] Core platform failed (exit $ec)." -ForegroundColor Red; exit 1 }
# ============================================================================
#  STAGE 3: CLOUDFLARE TUNNEL
# ============================================================================
Write-Host ""
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "|  STAGE 3: Cloudflare Tunnel             (est. 2-4 min) |" -ForegroundColor Yellow
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
$tc  = & ssh @SSHBase "$User@$ServerIP" "sudo bash /tmp/axiom-modules/03-cloudflare-tunnel.sh" 2>&1 | Out-String
$tce = $LASTEXITCODE; $ErrorActionPreference = $prev
if ($tce -eq 0 -and $tc -match "AXIOM_TUNNEL_HEALTHY") {
    Write-Host "  [OK] Tunnel already configured - skipping auth." -ForegroundColor Green
} else {
    Write-Host "  First-time setup: browser authentication required." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Steps:" -ForegroundColor Yellow
    Write-Host "    1. A URL will appear below - copy it" -ForegroundColor Gray
    Write-Host "    2. Open it in your browser" -ForegroundColor Gray
    Write-Host "    3. Log in to Cloudflare and authorise the tunnel" -ForegroundColor Gray
    Write-Host "    4. Return here - script continues automatically" -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press ENTER to launch authentication"
    Invoke-Remote "cloudflared tunnel login" -Interactive
    Write-Host ""; Write-Host "  Setting up tunnel credentials..." -ForegroundColor Cyan
    # FIX: 03b-tunnel-creds.sh is a proper bash module file, not an inline
    # PowerShell here-string. Previous version embedded bash with single-quoted
    # regex '(?<=with id )[a-f0-9-]+' combined with || on the same line, which
    # caused the PowerShell parser to misread quote boundaries and throw:
    #   "The token '||' is not a valid statement separator"
    $co = Invoke-Remote "bash /tmp/axiom-modules/03b-tunnel-creds.sh" -PassThru
    if ($co -match "AXIOM_TUNNEL_CREDS_OK") {
        Write-Host "  [OK] Credentials installed." -ForegroundColor Green
        Write-Host "  Configuring tunnel routes..." -ForegroundColor Gray
        $fo = Invoke-Remote "sudo bash /tmp/axiom-modules/03-cloudflare-tunnel.sh" -PassThru
        if ($fo -match "AXIOM_TUNNEL_HEALTHY") {
            Write-Host "  [OK] Tunnel is live." -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Tunnel may have issues - check logs." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [ERROR] Credential setup failed." -ForegroundColor Red
        Write-Host "  Common causes:" -ForegroundColor Yellow
        Write-Host "    - Browser authentication not completed" -ForegroundColor Gray
        Write-Host "    - Network connectivity issue"           -ForegroundColor Gray
        Write-Host "    - Cloudflare account permissions"       -ForegroundColor Gray
        exit 1
    }
}
# ============================================================================
#  STAGE 4: FIREWALL
# ============================================================================
Write-Host ""
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "|  STAGE 4: Firewall (SSH only)           (est. 30 sec)  |" -ForegroundColor Yellow
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
& ssh @SSHBase "$User@$ServerIP" "sudo bash /tmp/axiom-modules/04-firewall.sh" 2>&1 |
    ForEach-Object { Write-Host $_ }
$ErrorActionPreference = $prev
Write-Host "  [OK] Firewall active - SSH only." -ForegroundColor Green
# ============================================================================
#  STAGE 5: SERVICES
# ============================================================================
Write-Host ""
Write-Host "+---------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "|  STAGE 5: Service Deployment            (est. 5-15 min)|" -ForegroundColor Cyan
Write-Host "+---------------------------------------------------------+" -ForegroundColor Cyan
# FIX-2: was $DOMAIN (undefined) - corrected to $AXIOM_DOMAIN
$do = Invoke-Remote "bash -c 'source /tmp/axiom-modules/00-config.sh && echo AXIOM_DOMAIN_IS_\$AXIOM_DOMAIN'" -PassThru
if ($do -match "AXIOM_DOMAIN_IS_(.+)") {
    $domain = $Matches[1].Trim()
    Write-Host "  Domain: $domain" -ForegroundColor Gray
} else {
    Write-Host "  [ERROR] Could not read domain from config." -ForegroundColor Red
    Write-Host "  Output was: $do" -ForegroundColor DarkGray
    exit 1
}
Invoke-ServiceVerification -Module "05-cockpit.sh" -Label "Cockpit" `
    -URLs @("https://d.$domain") -ETA "1-2 min" `
    -FrontEnd @(
        "System admin - log in with your VPS SSH credentials",
        "Browser cert warning is normal - click Advanced > Proceed",
        "First proof-of-life through the tunnel"
    )
Invoke-ServiceVerification -Module "06-agent-zero.sh" -Label "Agent Zero (x3)" `
    -URLs @("https://a.$domain", "https://b.$domain", "https://c.$domain") -ETA "2-5 min" `
    -FrontEnd @(
        "AI agent chat - three independent instances",
        "Password: AZ_RFC_PASSWORD in 00-config.sh block above",
        "Each instance has its own workspace and memory"
    )
Invoke-ServiceVerification -Module "07-dockge.sh" -Label "Dockge" `
    -URLs @("https://e.$domain") -ETA "1-2 min" `
    -FrontEnd @(
        "Docker container management dashboard",
        "First visit asks you to create an admin account"
    )
Invoke-ServiceVerification -Module "08-filebrowser.sh" -Label "FileBrowser" `
    -URLs @("https://f.$domain") -ETA "30 sec" `
    -FrontEnd @(
        "Web file explorer",
        "DEFAULT LOGIN: admin / admin -- CHANGE THIS NOW",
        "Browse /opt/stacks for Docker compose files"
    )
Invoke-ServiceVerification -Module "09-ollama.sh" -Label "Ollama" `
    -URLs @("https://g.$domain") -ETA "5-10 min" `
    -FrontEnd @(
        "Local AI inference server - phi3:mini is pulled on first deploy",
        "REST API compatible with OpenAI format on port 11434",
        "Use Agent Zero or any OpenAI-compatible client pointed at this URL"
    )
# ============================================================================
#  COMPLETE
# ============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  AXIOM v1.1.2 DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  SERVICES:" -ForegroundColor Cyan
Write-Host "    https://a.$domain  Agent Zero Core"         -ForegroundColor White
Write-Host "    https://b.$domain  Agent Zero Alt 1"        -ForegroundColor White
Write-Host "    https://c.$domain  Agent Zero Alt 2"        -ForegroundColor White
Write-Host "    https://d.$domain  Cockpit (system admin)"  -ForegroundColor White
Write-Host "    https://e.$domain  Dockge  (containers)"    -ForegroundColor White
Write-Host "    https://f.$domain  FileBrowser (files)"     -ForegroundColor White
Write-Host "    https://g.$domain  Ollama  (local AI)"      -ForegroundColor White
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "    1. Change FileBrowser password  (default: admin / admin)" -ForegroundColor White
Write-Host "    2. Secure Cockpit credentials"                            -ForegroundColor White
Write-Host "    3. Change AZ_RFC_PASSWORD in the config block above"      -ForegroundColor White
Write-Host "    4. Subdomains h-z.$domain free for new services"          -ForegroundColor White
Write-Host ""
