# Adding Services to Axiom

This guide explains how to add new services to your Axiom deployment.

## Quick Overview

Adding a service involves three main steps:
1. **Reserve a subdomain** in the configuration
2. **Create a deployment module** 
3. **Update the Cloudflare Tunnel** configuration

## Step-by-Step Guide

### Step 1: Update Configuration

Edit `modules/00-config.sh` and add your service to the `SERVICES` array:

```bash
SERVICES=(
    [a]="agent-zero-core|5000|80|agent0ai/agent-zero:latest|Primary Agent Zero"
    [b]="agent-zero-alt1|50001|80|agent0ai/agent-zero:latest|Secondary Agent Zero"
    [c]="agent-zero-alt2|8000|80|agent0ai/agent-zero:latest|Tertiary Agent Zero"
    [d]="cockpit|9090|9090|SYSTEM|System administration panel"
    [e]="dockge|5001|5001|louislam/dockge:1|Docker container management"
    [f]="filebrowser|8080|80|filebrowser/filebrowser:latest|Web file manager"
    [g]="myservice|8888|80|myorg/myimage:latest|My Custom Service"  # <- NEW
)
```

**Format:** `[letter]="name|host_port|container_port|image|description"`

- **letter**: Subdomain (g -> g.willowcherry.us)
- **name**: Docker container name
- **host_port**: Port on the VPS host
- **container_port**: Port inside the container
- **image**: Docker image name, or "SYSTEM" for native services
- **description**: Human-readable label

### Step 2: Create Deployment Module

Create a new file `modules/09-myservice.sh` (use the next number in sequence):

```bash
#!/bin/bash
# ============================================================================
#  AXIOM MODULE 09 - MY CUSTOM SERVICE
# ============================================================================
#  Description of what this service does.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-config.sh"
source "$SCRIPT_DIR/lib.sh"

require_root

log "=== MODULE 09: My Custom Service ==="

# Get service info from config
entry="${SERVICES[g]}"
name=$(svc_name "$entry")
port=$(svc_port "$entry")
cport=$(svc_cport "$entry")
image=$(svc_image "$entry")
desc=$(svc_desc "$entry")

log "Deploying $desc on port $port..."

# Remove existing container if present
remove_container "$name"

# Create data directory (if needed)
data_dir="$AXIOM_STACKS_DIR/myservice"
ensure_dir "$data_dir"

# Deploy the container
docker run -d \
    --name "$name" \
    --restart unless-stopped \
    -p "${port}:${cport}" \
    -v "${data_dir}:/data" \
    -e MY_ENV_VAR="value" \
    "$image"

# Wait for container to be ready
wait_for_container "$name" 30

# Verify it's working
check_http "http://localhost:${port}" 30

log_success "$desc deployed: https://g.${AXIOM_DOMAIN}"
log "=== MODULE 09: Complete ==="
```

Make it executable:
```bash
chmod +x modules/09-myservice.sh
```

### Step 3: Update Tunnel Configuration

The Cloudflare Tunnel configuration is automatically generated from the `SERVICES` array in `modules/03-cloudflare-tunnel.sh`. You don't need to manually edit it.

However, you need to add the subdomain DNS record in Cloudflare:

1. Re-run the tunnel setup module:
   ```bash
   sudo bash modules/03-cloudflare-tunnel.sh
   ```

2. Or manually add to `/etc/cloudflared/config.yml`:
   ```yaml
   ingress:
     - hostname: g.willowcherry.us
       service: http://localhost:8888
   ```

3. Restart cloudflared:
   ```bash
   sudo systemctl restart cloudflared
   ```

### Step 4: Deploy Your Service

Run your deployment module:
```bash
sudo bash modules/09-myservice.sh
```

Test access at: `https://g.willowcherry.us` (replace with your subdomain)

## Common Service Types

### Docker Container Service
Most services follow the pattern shown above. Key considerations:
- Choose an unused port
- Mount volumes for persistent data
- Set necessary environment variables
- Use `--restart unless-stopped` for auto-recovery

### System Service (Non-Docker)
For services installed via apt/systemd:

```bash
# Set image to "SYSTEM" in config
[g]="myservice|8080|8080|SYSTEM|My System Service"

# In your module:
apt-get install -y mypackage
systemctl start myservice
systemctl enable myservice
```

### Docker Compose Stack
For multi-container applications:

```bash
# Create compose file
cat > "$AXIOM_STACKS_DIR/myapp/compose.yaml" << EOF
services:
  web:
    image: nginx:latest
    ports:
      - "8888:80"
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret
EOF

# Deploy with docker compose
cd "$AXIOM_STACKS_DIR/myapp"
docker compose up -d
```

## Best Practices

1. **Port Selection**: Use ports > 5000 to avoid conflicts with common services
2. **Data Persistence**: Always mount volumes for data that should survive container recreation
3. **Health Checks**: Use `wait_for_container` and `check_http` to verify deployment
4. **Logging**: Use the `log`, `log_success`, and `log_error` functions from `lib.sh`
5. **Cleanup**: Use `remove_container` before deploying to handle reinstalls gracefully
6. **Security**: 
   - Don't expose additional ports through the firewall
   - Use Cloudflare Tunnel for all web access
   - Change default passwords immediately
   - Use environment variables for secrets

## Troubleshooting

### Service won't start
```bash
# Check container logs
docker logs myservice

# Check if port is in use
netstat -tulpn | grep 8888

# Verify image was pulled
docker images | grep myimage
```

### Can't access through tunnel
```bash
# Check cloudflared status
systemctl status cloudflared

# View tunnel logs
journalctl -u cloudflared -n 50

# Test local access first
curl http://localhost:8888
```

### Container keeps restarting
```bash
# Check restart policy
docker inspect myservice | grep -A 5 RestartPolicy

# View recent restarts
docker ps -a | grep myservice

# Check system resources
docker stats --no-stream
```

## Advanced Topics

### Custom Networks
Create isolated networks for service groups:
```bash
docker network create myapp-net
docker run -d --name web --network myapp-net ...
docker run -d --name db --network myapp-net ...
```

### Resource Limits
Prevent services from consuming too much:
```bash
docker run -d \
    --name myservice \
    --memory="512m" \
    --cpus="0.5" \
    ...
```

### Automatic Backups
Use Dockge's built-in features or create a backup script:
```bash
#!/bin/bash
docker exec myservice pg_dump -U postgres mydb > /backup/mydb-$(date +%Y%m%d).sql
```

## Need Help?

- Check the logs: `/var/log/axiom-deploy.log`
- Review module source code in `modules/`
- Use Cockpit for system monitoring: `https://d.willowcherry.us`
- Use Dockge for container management: `https://e.willowcherry.us`
