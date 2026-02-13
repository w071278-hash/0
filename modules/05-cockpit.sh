#!/bin/bash
# ============================================================================
#  AXIOM MODULE 05 - COCKPIT
# ============================================================================
#  Installs Cockpit web-based system administration interface.
#  This is the first "proof of life" service accessible through the tunnel.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 05: Cockpit Installation ==="

# Install Cockpit
if command_exists cockpit-bridge; then
    log "Cockpit is already installed"
else
    log "Installing Cockpit..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cockpit cockpit-docker
    log_success "Cockpit installed"
fi

# Enable and start Cockpit service
log "Starting Cockpit service..."
systemctl start cockpit.socket
systemctl enable cockpit.socket

# Wait a moment for service to be ready
sleep 3

if service_active cockpit.socket; then
    log_success "Cockpit is active"
    
    # Get the Cockpit subdomain from services
    for letter in "${!SERVICES[@]}"; do
        entry="${SERVICES[$letter]}"
        name=$(svc_name "$entry")
        if [[ "$name" == "cockpit" ]]; then
            log "Cockpit is accessible at: https://${letter}.${AXIOM_DOMAIN}"
            log "Local port: $(svc_port "$entry")"
            break
        fi
    done
else
    log_error "Cockpit failed to start" 1
fi

log "=== MODULE 05: Complete ==="
log "Cockpit provides web-based system administration."
log "Log in with your system credentials."
