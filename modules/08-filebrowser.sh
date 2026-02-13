#!/bin/bash
# ============================================================================
#  AXIOM MODULE 08 - FILE BROWSER
# ============================================================================
#  Deploys FileBrowser - a web-based file management interface.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 08: FileBrowser Deployment ==="

# Get FileBrowser service info
entry="${SERVICES[f]}"
name=$(svc_name "$entry")
port=$(svc_port "$entry")
cport=$(svc_cport "$entry")
image=$(svc_image "$entry")
desc=$(svc_desc "$entry")

log "Deploying $desc on port $port..."

# Remove existing container
remove_container "$name"

# Create data directory
data_dir="$AXIOM_STACKS_DIR/filebrowser"
ensure_dir "$data_dir"

# Deploy FileBrowser with root access to stacks directory
docker run -d \
    --name "$name" \
    --restart unless-stopped \
    -p "${port}:${cport}" \
    -v "$AXIOM_STACKS_DIR:/srv" \
    -v "${data_dir}/database.db:/database.db" \
    -v "${data_dir}/filebrowser.json:/.filebrowser.json" \
    "$image"

# Wait for container to be ready
wait_for_container "$name" 30

# Verify HTTP endpoint
check_http "http://localhost:${port}" 30 || log_warn "$name HTTP check failed (may still be initializing)"

log_success "$desc deployed: https://f.${AXIOM_DOMAIN}"

log "=== MODULE 08: Complete ==="
log "FileBrowser default credentials: admin / admin"
log "IMPORTANT: Change the default password on first login!"
