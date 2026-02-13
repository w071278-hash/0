#!/bin/bash
# ============================================================================
#  AXIOM MODULE 01 - SYSTEM PREPARATION
# ============================================================================
#  Updates the system and conditionally reboots if kernel updates were applied.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 01: System Preparation ==="
log "Updating package lists..."

# Update package lists
apt-get update -qq

log "Upgrading installed packages (this may take several minutes)..."

# Perform full upgrade
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

log_success "System packages updated"

# Check if reboot is required (Ubuntu/Debian creates this file when reboot needed)
if [[ -f /var/run/reboot-required ]]; then
    log_warn "System reboot is required (kernel or critical updates applied)"
    
    if [[ "${AXIOM_AUTO_REBOOT:-0}" == "1" ]]; then
        log "Auto-reboot enabled. System will reboot in 10 seconds..."
        log "After reboot, re-run the deployment script to continue."
        sleep 10
        reboot
    else
        log "Please reboot the system manually and re-run the deployment."
        log "You can enable auto-reboot by setting AXIOM_AUTO_REBOOT=1"
        exit 0
    fi
else
    log_success "No reboot required. Proceeding with deployment."
fi

log "=== MODULE 01: Complete ==="
