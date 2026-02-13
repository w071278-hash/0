#!/bin/bash
# ============================================================================
#  PROJECT AXIOM v1.0.0 - CONFIGURATION
# ============================================================================
#  Single source of truth. Every module sources this file first.
#
#  DOMAIN STRATEGY:
#    Subdomains a-z.willowcherry.us are allocated sequentially to services
#    in deployment order. To add a service, claim the next free letter.
#
#  DEPLOYMENT ORDER (foundation-up):
#    01  System prep (update/upgrade/conditional reboot)
#    02  Core platform (Docker, base packages)
#    03  Cloudflare tunnel (secure pipe — everything after is browser-verifiable)
#    04  Firewall (lock perimeter — only SSH + tunnel survive)
#    05  Cockpit (d.) — first proof-of-life through the tunnel
#    06  Agent Zero triad (a. b. c.)
#    07  Dockge (e.)
#    08  FileBrowser (f.)
# ============================================================================

AXIOM_VERSION="1.0.0"
AXIOM_DOMAIN="willowcherry.us"
AXIOM_TUNNEL_NAME="axiom-tunnel"
AXIOM_LOG="/var/log/axiom-deploy.log"
AXIOM_CREDS_DIR="/etc/cloudflared"
AXIOM_STACKS_DIR="/opt/stacks"

# --- SERVICE REGISTRY ---
# Format: SERVICES[letter]="name|host_port|container_internal_port|image|description"
#   - letter         = subdomain (a -> a.willowcherry.us)
#   - name           = Docker container name (or systemd service name)
#   - host_port      = port on the host machine
#   - container_port = port inside the container (mapped to host_port)
#   - image          = Docker image, or "SYSTEM" for native services
#   - description    = human-readable label

declare -A SERVICES
SERVICES=(
    [a]="agent-zero-core|5000|80|agent0ai/agent-zero:latest|Primary Agent Zero"
    [b]="agent-zero-alt1|50001|80|agent0ai/agent-zero:latest|Secondary Agent Zero"
    [c]="agent-zero-alt2|8000|80|agent0ai/agent-zero:latest|Tertiary Agent Zero"
    [d]="cockpit|9090|9090|SYSTEM|System administration panel"
    [e]="dockge|5001|5001|louislam/dockge:1|Docker container management"
    [f]="filebrowser|8080|80|filebrowser/filebrowser:latest|Web file manager"
    # [g] through [z] — available for future services
)

# --- AGENT ZERO SHARED CONFIG ---
AZ_RFC_PASSWORD="AxiomSecureRFC2026!"
AZ_ALLOWED_ORIGINS="*"

# --- FIELD PARSERS ---
svc_name()      { echo "$1" | cut -d'|'-f1; }
svc_port()      { echo "$1" | cut -d'|'-f2; }
svc_cport()     { echo "$1" | cut -d'|'-f3; }
svc_image()     { echo "$1" | cut -d'|'-f4; }
svc_desc()      { echo "$1" | cut -d'|'-f5; }

# Return assigned subdomain letters in sorted order.
assigned_letters() {
    printf '%s\n' "${!SERVICES[@]}" | sort
}