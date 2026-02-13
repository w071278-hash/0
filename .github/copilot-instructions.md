# Copilot Instructions for Project Axiom

## Project Overview

**Axiom v1.1.0** is a complete, batteries-included VPS deployment system for AI agents, system administration, and container management—secured behind Cloudflare Tunnel. It's a one-command deployment system that transforms a fresh Ubuntu VPS into a fully-configured platform.

## Tech Stack

- **Primary Language**: Bash (deployment modules)
- **Windows Controller**: PowerShell + Batch (.cmd launcher)
- **Target OS**: Ubuntu 20.04/22.04 LTS
- **Container Platform**: Docker + Docker Compose
- **Secure Access**: Cloudflare Tunnel (cloudflared)
- **Firewall**: UFW (Uncomplicated Firewall)
- **Deployed Services**:
  - Agent Zero (AI coding agents) - 3 instances
  - Cockpit (system administration)
  - Dockge (Docker container management)
  - FileBrowser (web file management)

## Project Structure

```
.
├── axiom.cmd                 # Windows batch launcher → PowerShell controller
├── setup.cmd                 # Alternative setup script
├── modules/                  # Bash deployment modules (run on VPS)
│   ├── 00-config.sh         # Single source of truth for configuration
│   ├── lib.sh               # Shared library (logging, container management)
│   ├── 01-system-prep.sh    # System updates and preparation
│   ├── 02-core-platform.sh  # Docker and essential packages
│   ├── 03-cloudflare-tunnel.sh # Cloudflare Tunnel setup
│   ├── 04-firewall.sh       # UFW firewall configuration
│   ├── 05-cockpit.sh        # Cockpit deployment
│   ├── 06-agent-zero.sh     # Agent Zero trio deployment
│   ├── 07-dockge.sh         # Dockge deployment
│   └── 08-filebrowser.sh    # FileBrowser deployment
├── docs/                     # User documentation
│   ├── adding-services.md   # Guide for adding new services
│   └── github-guide.md      # Git basics for Axiom users
└── README.md                # Main documentation
```

## Key Commands

### Testing & Validation

```bash
# Test deployment on a VPS (run from Windows)
.\axiom.cmd

# Test individual module on the VPS (SSH into VPS first)
sudo bash modules/05-cockpit.sh

# Check deployment logs on VPS
sudo tail -f /var/log/axiom-deploy.log
sudo grep ERROR /var/log/axiom-deploy.log

# Verify services are running on VPS
docker ps
docker logs <container-name>

# Check Cloudflare Tunnel status on VPS
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -n 50

# Verify firewall on VPS
sudo ufw status
```

### Development

```bash
# Clone repository
git clone https://github.com/w071278-hash/0.git
cd 0

# View module configuration
cat modules/00-config.sh

# Check what's changed
git --no-pager status
git --no-pager diff
```

## Code Style Guidelines

### Bash Scripts (modules/*.sh)

1. **File Headers**: Every module must start with a header block:
   ```bash
   #!/bin/bash
   # ============================================================================
   #  PROJECT AXIOM - MODULE NAME
   # ============================================================================
   #  Brief description of what this module does.
   # ============================================================================
   ```

2. **Configuration Loading**: All modules must source config first:
   ```bash
   # Source configuration
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "${SCRIPT_DIR}/00-config.sh"
   source "${SCRIPT_DIR}/lib.sh"
   ```

3. **Logging**: Use the shared logging functions from `lib.sh`:
   - `log "message"` - Standard logging
   - `log_success "message"` - Success messages
   - `log_error "message" [exit_code]` - Error messages (optionally exit)
   - `log_warn "message"` - Warning messages

4. **Error Handling**: Use `set -e` and proper error messages:
   ```bash
   set -e  # Exit on error
   ```

5. **Idempotency**: Modules should be re-runnable without breaking:
   ```bash
   # Check if already exists before creating
   if ! docker ps -a --format '{{.Names}}' | grep -q "^container-name$"; then
       # Create container
   fi
   ```

6. **Comments**: Use inline comments for complex logic, but prefer self-documenting code:
   ```bash
   # Good: Self-documenting
   wait_for_container "agent-zero-core" 120
   
   # Avoid: Over-commenting obvious code
   # This starts the container
   docker start container  # starts container
   ```

### PowerShell (axiom.cmd embedded script)

1. **Error Handling**: Use `$ErrorActionPreference = "Stop"`
2. **Output**: Use `Write-Host` with color coding for user feedback
3. **Path Handling**: Always use `Join-Path` for cross-platform compatibility

### General

- **No hardcoded credentials**: Use environment variables or configuration files
- **No secrets in code**: Credentials should be passed as parameters or read from secure locations
- **Consistent naming**: Use hyphenated lowercase for container names (e.g., `agent-zero-core`)
- **Service ports**: Document all port mappings in `00-config.sh` SERVICES array

## Deployment Flow

The deployment follows a specific order (foundation-up approach):

1. **01-system-prep.sh**: System updates, upgrades, conditional reboot
2. **02-core-platform.sh**: Install Docker, Docker Compose, essential packages
3. **03-cloudflare-tunnel.sh**: Set up Cloudflare Tunnel (secure access pipe)
4. **04-firewall.sh**: Lock down firewall - only SSH + tunnel survive
5. **05-cockpit.sh**: First service proof-of-life through the tunnel
6. **06-agent-zero.sh**: Deploy three Agent Zero instances
7. **07-dockge.sh**: Deploy container management UI
8. **08-filebrowser.sh**: Deploy web file manager

Each module builds on the previous one. Never skip modules unless you understand the dependencies.

## Boundaries and Constraints

### DO NOT:

1. **Never modify core configuration without understanding impact**:
   - `00-config.sh` is the single source of truth
   - Changes affect all modules
   - Test thoroughly before committing

2. **Never expose additional ports**:
   - All web services MUST go through Cloudflare Tunnel
   - Only SSH (port 22) should be accessible directly
   - Firewall rules are intentionally restrictive

3. **Never hardcode IPs or domains**:
   - Use configuration variables from `00-config.sh`
   - Support multiple environments

4. **Never commit secrets**:
   - No credentials in code
   - No API keys in repository
   - Use environment variables or external secret management

5. **Never break idempotency**:
   - Modules must be re-runnable
   - Check for existing resources before creating
   - Use proper cleanup on failure

6. **Never modify Docker base images**:
   - Use official images when possible
   - Document any custom image requirements
   - Pin versions for reproducibility

### DO:

1. **Always test on a fresh VPS**:
   - Verify full deployment from scratch
   - Check all services are accessible
   - Review logs for errors

2. **Always update documentation**:
   - README.md for user-facing changes
   - docs/ for guides and tutorials
   - Inline comments for complex logic

3. **Always maintain the service registry**:
   - Update SERVICES array in `00-config.sh`
   - Follow the subdomain allocation pattern (a-z)
   - Document new services

4. **Always use the shared library**:
   - Reuse functions from `lib.sh`
   - Add new shared functions to `lib.sh`, not individual modules
   - Keep modules focused on their specific task

5. **Always check dependencies**:
   - Ensure required services are running before depending on them
   - Use `wait_for_container` from `lib.sh`
   - Handle failures gracefully

## Adding New Services

To add a new service, follow this workflow:

1. **Update `00-config.sh`**: Add service to SERVICES array
2. **Create deployment module**: Follow naming pattern (09-myservice.sh)
3. **Source config and lib**: `source 00-config.sh` and `source lib.sh`
4. **Implement idempotent deployment**: Check, create, verify
5. **Update Cloudflare Tunnel**: Re-run module 03 or update manually
6. **Test thoroughly**: Full deployment on fresh VPS
7. **Update README.md**: Document new service and its subdomain
8. **Update docs/adding-services.md**: Add example if needed

See `docs/adding-services.md` for detailed step-by-step instructions.

## Testing Strategy

1. **Pre-deployment**: Run pre-flight checks (built into axiom.cmd)
2. **Module testing**: Test each module individually on VPS
3. **Integration testing**: Full deployment on fresh VPS
4. **Service verification**: Access each service via subdomain
5. **Log review**: Check `/var/log/axiom-deploy.log` for errors
6. **Container health**: Verify all containers are running and healthy

## Git Workflow

1. **Feature branches**: Create branch for each feature/fix
2. **Descriptive commits**: Use clear, concise commit messages
3. **Test before PR**: Always test on fresh VPS before pull request
4. **Documentation**: Update docs with code changes
5. **Small, focused changes**: One feature or fix per PR

## Common Pitfalls

1. **Port conflicts**: Always check `00-config.sh` for used ports
2. **Service dependencies**: Respect deployment order
3. **Cloudflare Tunnel**: Must be configured before accessing services
4. **SSH key management**: Keep keys secure, never commit them
5. **Module execution context**: Modules run on VPS, not Windows client
6. **Docker volumes**: Data persists in `/opt/stacks`, plan accordingly

## Security Considerations

1. **All services behind Cloudflare Tunnel**: No direct port exposure
2. **SSH key authentication only**: No password-based SSH
3. **UFW firewall**: Locked down to SSH only
4. **Container isolation**: Each service in separate container
5. **Environment variables**: Secrets stored outside code
6. **Default credentials**: Must be changed on first use (especially FileBrowser)

## Good Examples

### Adding a logging statement
```bash
log "Starting deployment of MyService..."
log_success "MyService deployed successfully"
log_error "Failed to start MyService" 1  # Log and exit
```

### Checking if container exists
```bash
if ! docker ps -a --format '{{.Names}}' | grep -q "^my-service$"; then
    log "Creating my-service container..."
    # Create container
else
    log "Container my-service already exists"
fi
```

### Waiting for service to be ready
```bash
# Deploy container
docker run -d --name my-service ...

# Wait for it to be healthy
wait_for_container "my-service" 120  # 2 minute timeout
```

### Using service registry
```bash
# Extract service info from config
# 'g' represents the next available subdomain letter after a-f
IFS='|' read -r name host_port container_port image description <<< "${SERVICES[g]}"
log "Deploying $name ($description) on port $host_port"
```

## Questions to Ask Before Making Changes

1. Does this change affect the deployment order?
2. Are there any new port requirements?
3. Does this require Cloudflare Tunnel reconfiguration?
4. Is this change idempotent?
5. Have I tested on a fresh VPS?
6. Does the documentation need updating?
7. Are there any security implications?
8. Does this break existing deployments?

---

**Remember**: Axiom is designed for simplicity and reliability. Keep changes minimal, test thoroughly, and prioritize user experience in the deployment process.
