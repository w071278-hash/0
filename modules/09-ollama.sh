#!/bin/bash
# ============================================================================
#  AXIOM MODULE 09 - OLLAMA
# ============================================================================
#  Deploys Ollama - a local AI model inference server.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 09: Ollama ==="

# Get Ollama service info
entry="${SERVICES[g]}"
name=$(svc_name "$entry"); port=$(svc_port "$entry")
cport=$(svc_cport "$entry"); image=$(svc_image "$entry")
desc=$(svc_desc "$entry")

log "Deploying $desc on port $port..."

# Remove existing container
remove_container "$name"

# Create data directory
data_dir="$AXIOM_STACKS_DIR/ollama"
ensure_dir "$data_dir"

# Deploy Ollama with persistent model storage
docker run -d --name "$name" --restart unless-stopped \
    -p "${port}:${cport}" \
    -v "${data_dir}:/root/.ollama" \
    "$image"

# Wait for container to be ready
wait_for_container "$name" 60

# Verify HTTP endpoint and emit health signal
if check_http "http://localhost:${port}" 60; then
    echo "AXIOM_HEALTH_PASS"
else
    log_warn "$name HTTP check failed"
    echo "AXIOM_HEALTH_FAIL"
fi

# Pull the default model
log "Pulling phi3:mini (this may take several minutes)..."
docker exec "$name" ollama pull phi3:mini

log_success "$desc: https://g.${AXIOM_DOMAIN}"

log "=== MODULE 09: Complete ==="
