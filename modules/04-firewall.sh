#!/bin/bash
# ============================================================================
#  AXIOM MODULE 04 - FIREWALL CONFIGURATION
# ============================================================================
#  Configures UFW (Uncomplicated Firewall) to allow only SSH and deny all else.
#  All other services are accessed through the Cloudflare Tunnel.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 04: Firewall Configuration ==="

# Install UFW if not present
if ! command_exists ufw; then
    log "Installing UFW..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ufw
    log_success "UFW installed"
fi

# Reset UFW to default settings
log "Configuring UFW rules..."
ufw --force reset >/dev/null 2>&1

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (important: do this before enabling UFW!)
ufw allow 22/tcp comment 'SSH access'

log "Firewall rules configured:"
log "  - SSH (port 22): ALLOWED"
log "  - All other incoming: DENIED"
log "  - All outgoing: ALLOWED"

# Enable UFW
log "Enabling firewall..."
ufw --force enable

if service_active ufw; then
    log_success "Firewall is active"
else
    log_error "Failed to activate firewall" 1
fi

# Display status
log "Current firewall status:"
ufw status verbose | tee -a "$AXIOM_LOG"

log "=== MODULE 04: Complete ==="
log "Note: All services are accessible only through Cloudflare Tunnel"
