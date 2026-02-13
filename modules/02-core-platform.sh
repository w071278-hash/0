#!/bin/bash
# ============================================================================
#  AXIOM MODULE 02 - CORE PLATFORM
# ============================================================================
#  Installs Docker, Docker Compose, and essential system packages.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 02: Core Platform Installation ==="

# Install essential packages
log "Installing essential packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    git \
    wget \
    unzip \
    netcat \
    jq

log_success "Essential packages installed"

# Check if Docker is already installed
if command_exists docker; then
    log "Docker is already installed: $(docker --version)"
else
    log "Installing Docker..."
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    log_success "Docker installed: $(docker --version)"
fi

# Ensure Docker service is running
if ! service_active docker; then
    log "Starting Docker service..."
    systemctl start docker
    systemctl enable docker
fi

log_success "Docker service is active"

# Verify Docker is working
if ! docker ps >/dev/null 2>&1; then
    log_error "Docker is installed but not functioning correctly" 1
fi

log "Docker Compose version: $(docker compose version)"

# Create stacks directory for organized deployments
ensure_dir "$AXIOM_STACKS_DIR"

log "=== MODULE 02: Complete ==="
