#!/bin/bash
# ============================================================================
#  AXIOM MODULE 03 - CLOUDFLARE TUNNEL
# ============================================================================
#  Installs and configures Cloudflare Tunnel for secure access to services.
#  Requires tunnel credentials JSON to be present at $AXIOM_CREDS_DIR/<tunnel-id>.json
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 03: Cloudflare Tunnel Setup ==="

# Check if cloudflared is already installed
if command_exists cloudflared; then
    log "cloudflared is already installed: $(cloudflared --version)"
else
    log "Installing cloudflared..."
    
    # Download and install cloudflared for AMD64 (adjust for other architectures if needed)
    ARCH=$(dpkg --print-architecture)
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb
    dpkg -i cloudflared-linux-${ARCH}.deb
    rm cloudflared-linux-${ARCH}.deb
    
    log_success "cloudflared installed: $(cloudflared --version)"
fi

# Ensure credentials directory exists
ensure_dir "$AXIOM_CREDS_DIR"

# Check for tunnel credentials
CRED_FILE=$(find "$AXIOM_CREDS_DIR" -name "*.json" -type f | head -n 1)

if [[ -z "$CRED_FILE" ]]; then
    log_error "No tunnel credentials found in $AXIOM_CREDS_DIR" 1
fi

TUNNEL_ID=$(basename "$CRED_FILE" .json)
log "Found tunnel credentials: $TUNNEL_ID"

# Create tunnel configuration file
CONFIG_FILE="$AXIOM_CREDS_DIR/config.yml"
log "Creating tunnel configuration: $CONFIG_FILE"

cat > "$CONFIG_FILE" << EOF
tunnel: $TUNNEL_ID
credentials-file: $CRED_FILE

ingress:
$(for letter in $(assigned_letters); do
    entry="${SERVICES[$letter]}"
    name=$(svc_name "$entry")
    port=$(svc_port "$entry")
    echo "  - hostname: ${letter}.${AXIOM_DOMAIN}"
    echo "    service: http://localhost:${port}"
done)
  # Catch-all rule (required by cloudflared)
  - service: http_status:404
EOF

log_success "Tunnel configuration created"

# Install as systemd service
log "Installing cloudflared as systemd service..."
cloudflared service install

# Copy configuration to the default location
cp "$CONFIG_FILE" /etc/cloudflared/config.yml

# Start the tunnel service
log "Starting cloudflared service..."
systemctl start cloudflared
systemctl enable cloudflared

# Wait for tunnel to be ready
sleep 5

if service_active cloudflared; then
    log_success "Cloudflare Tunnel is active"
else
    log_error "Cloudflare Tunnel failed to start" 1
fi

log "=== MODULE 03: Complete ==="
log "Tunnel is now routing traffic from:"
for letter in $(assigned_letters); do
    echo "  https://${letter}.${AXIOM_DOMAIN}"
done
