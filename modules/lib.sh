#!/bin/bash
# ============================================================================
#  PROJECT AXIOM - SHARED LIBRARY
# ============================================================================
#  Reusable functions for logging, container management, and health checks.
#  Sourced by all deployment modules.
# ============================================================================

# --- LOGGING ---

# Log a message with timestamp to both console and log file.
# Usage: log "message"
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "${AXIOM_LOG:-/var/log/axiom-deploy.log}"
}

# Log an error message and optionally exit.
# Usage: log_error "error message" [exit_code]
log_error() {
    local msg="[ERROR] $1"
    log "$msg"
    if [[ -n "$2" ]]; then
        exit "$2"
    fi
}

# Log a success message.
# Usage: log_success "success message"
log_success() {
    log "[SUCCESS] $1"
}

# Log a warning message.
# Usage: log_warn "warning message"
log_warn() {
    log "[WARN] $1"
}

# --- CONTAINER MANAGEMENT ---

# Check if a Docker container is running.
# Usage: container_running "container_name"
# Returns: 0 if running, 1 if not
container_running() {
    local name="$1"
    docker ps --format '{{.Names}}' | grep -q "^${name}$"
}

# Wait for a container to be healthy or running.
# Usage: wait_for_container "container_name" [timeout_seconds]
# Returns: 0 if healthy/running, 1 if timeout
wait_for_container() {
    local name="$1"
    local timeout="${2:-60}"
    local elapsed=0
    
    log "Waiting for container '$name' to be ready (timeout: ${timeout}s)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        if container_running "$name"; then
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null)
            
            # If no health check defined, just check if running
            if [[ -z "$health" ]] || [[ "$health" == "healthy" ]]; then
                log_success "Container '$name' is ready"
                return 0
            fi
            
            # Container has health check but not healthy yet
            if [[ "$health" == "unhealthy" ]]; then
                log_error "Container '$name' is unhealthy" 1
            fi
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_error "Timeout waiting for container '$name'" 1
}

# Stop and remove a container if it exists.
# Usage: remove_container "container_name"
remove_container() {
    local name="$1"
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
        log "Removing existing container '$name'..."
        docker stop "$name" >/dev/null 2>&1 || true
        docker rm "$name" >/dev/null 2>&1 || true
        log_success "Container '$name' removed"
    fi
}

# --- HEALTH CHECKS ---

# Check if a URL is reachable with HTTP 200 status.
# Usage: check_http "http://localhost:8080" [timeout_seconds]
# Returns: 0 if reachable, 1 if not
check_http() {
    local url="$1"
    local timeout="${2:-60}"
    local elapsed=0
    
    log "Checking HTTP endpoint: $url (timeout: ${timeout}s)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            log_success "HTTP endpoint is reachable: $url"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_warn "HTTP endpoint not reachable: $url"
    return 1
}

# Check if a TCP port is open.
# Usage: check_port "localhost" "8080" [timeout_seconds]
# Returns: 0 if open, 1 if not
check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local elapsed=0
    
    log "Checking TCP port: ${host}:${port} (timeout: ${timeout}s)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_success "Port is open: ${host}:${port}"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_warn "Port is not open: ${host}:${port}"
    return 1
}

# --- SYSTEM CHECKS ---

# Check if a command exists.
# Usage: command_exists "docker"
# Returns: 0 if exists, 1 if not
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root.
# Usage: require_root
# Exits with error if not root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)" 1
    fi
}

# Check if a system service is active.
# Usage: service_active "docker"
# Returns: 0 if active, 1 if not
service_active() {
    systemctl is-active --quiet "$1"
}

# --- UTILITIES ---

# Create a directory if it doesn't exist.
# Usage: ensure_dir "/path/to/directory"
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log "Created directory: $dir"
    fi
}

# Ask user for yes/no confirmation.
# Usage: confirm "Are you sure?" && do_something
# Returns: 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    read -p "$prompt (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}
