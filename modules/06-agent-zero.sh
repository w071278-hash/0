#!/bin/bash
# ============================================================================
#  AXIOM MODULE 06 - AGENT ZERO
# ============================================================================
#  Deploys three instances of Agent Zero AI agent.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 06: Agent Zero Deployment ==="

# Agent Zero instances: a, b, c
AGENT_LETTERS=("a" "b" "c")

for letter in "${AGENT_LETTERS[@]}"; do
    entry="${SERVICES[$letter]}"
    name=$(svc_name "$entry")
    port=$(svc_port "$entry")
    cport=$(svc_cport "$entry")
    image=$(svc_image "$entry")
    desc=$(svc_desc "$entry")
    
    log "Deploying $desc ($name) on port $port..."
    
    # Remove existing container if present
    remove_container "$name"
    
    # Create data directory for this agent
    data_dir="$AXIOM_STACKS_DIR/agent-zero/${name}"
    ensure_dir "$data_dir"
    
    # Deploy Agent Zero container
    docker run -d \
        --name "$name" \
        --restart unless-stopped \
        -p "${port}:${cport}" \
        -v "${data_dir}:/app/data" \
        -e RFC_PASSWORD="$AZ_RFC_PASSWORD" \
        -e ALLOWED_ORIGINS="$AZ_ALLOWED_ORIGINS" \
        "$image"
    
    # Wait for container to be ready
    wait_for_container "$name" 30
    
    # Verify HTTP endpoint
    check_http "http://localhost:${port}" 30 || log_warn "$name HTTP check failed (may still be initializing)"
    
    log_success "$desc deployed: https://${letter}.${AXIOM_DOMAIN}"
done

log "=== MODULE 06: Complete ==="
log "All three Agent Zero instances are deployed and accessible through the tunnel."
