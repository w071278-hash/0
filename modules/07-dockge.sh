#!/bin/bash
# ============================================================================
#  AXIOM MODULE 07 - DOCKGE
# ============================================================================
#  Deploys Dockge - a fancy, easy-to-use Docker Compose stack manager.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 07: Dockge Deployment ==="

# Get Dockge service info
entry="${SERVICES[e]}"
name=$(svc_name "$entry")
port=$(svc_port "$entry")
cport=$(svc_cport "$entry")
image=$(svc_image "$entry")
desc=$(svc_desc "$entry")

log "Deploying $desc on port $port..."

# Remove existing container
remove_container "$name"

# Create data directories
data_dir="$AXIOM_STACKS_DIR/dockge"
ensure_dir "$data_dir"

# Deploy Dockge
docker run -d \
    --name "$name" \
    --restart unless-stopped \
    -p "${port}:${cport}" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${data_dir}:/app/data" \
    -v "$AXIOM_STACKS_DIR:/opt/stacks" \
    -e DOCKGE_STACKS_DIR=/opt/stacks \
    "$image"

# Wait for container to be ready
wait_for_container "$name" 30

# Verify HTTP endpoint
check_http "http://localhost:${port}" 30 || log_warn "$name HTTP check failed (may still be initializing)"

log_success "$desc deployed: https://e.${AXIOM_DOMAIN}"

log "=== MODULE 07: Complete ==="
log "Dockge provides a web UI for managing Docker Compose stacks."
log "On first access, you'll need to set up an admin account."
