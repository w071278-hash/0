# Axiom v1.1.0

**Complete, batteries-included VPS deployment system** for AI agents, system administration, and container management—secured behind Cloudflare Tunnel.

## What is Axiom?

Axiom is a one-command deployment system that transforms a fresh Ubuntu VPS into a fully-configured platform running:

- **Agent Zero** (x3) - AI coding agents with web interface
- **Cockpit** - Web-based system administration
- **Dockge** - Beautiful Docker container manager
- **FileBrowser** - Web-based file management
- **Cloudflare Tunnel** - Secure access without exposing ports

All services are accessible via HTTPS subdomains, with no ports exposed except SSH.

## ✨ New in v1.1.0

- **Smart SSH Key Discovery**: Automatically finds existing keys or guides you through generation
- **Dual Deployment Methods**: 
  - Paste key into VPS provider (recommended)
  - Password-based deployment (alternative)
- **5 Pre-flight Checks**: Validates Git, SSH, repo, modules, and connectivity before starting
- **OS Detection**: Automatically detects and displays VPS operating system
- **IP Configuration**: Verifies network setup and handles NAT scenarios
- **Enhanced Instructions**: Step-by-step guidance at every phase
- **Improved Error Handling**: Clear error messages with actionable troubleshooting steps

## Quick Start

### Prerequisites

- **Windows 10/11** with PowerShell
- **Git** for Windows
- **OpenSSH Client** (built into Windows 10/11)
- A **VPS** running Ubuntu 20.04 or 22.04
- A **Cloudflare account** with a domain
- **Cloudflare Tunnel** set up (instructions below)

### 1. Clone the Repository

```powershell
git clone https://github.com/w071278-hash/0.git
cd 0
```

### 2. Set Up Cloudflare Tunnel

Before deploying, you need a Cloudflare Tunnel:

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks → Tunnels**
3. Click **Create a tunnel**
4. Name it (e.g., "axiom-tunnel")
5. Download the **credentials JSON file** (you'll need this for deployment)
6. Add your subdomains (a-z.yourdomain.com) in the Public Hostname section, or do this after deployment

### 3. Run the Deployment

```powershell
.\axiom.cmd
```

The script will:
1. ✅ Run pre-flight checks
2. 🔑 Discover or generate SSH keys
3. 🚀 Guide you through VPS connection setup
4. 📦 Deploy all services automatically
5. 🎉 Provide access URLs for all services

**Estimated time:** 10-15 minutes

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Cloudflare Tunnel                  │
│            (HTTPS with automatic certs)             │
└──────────────────┬──────────────────────────────────┘
                   │
    ┌──────────────┼──────────────┬──────────────┐
    │              │              │              │
┌───▼───┐    ┌───▼───┐    ┌─────▼─────┐  ┌─────▼──────┐
│Agent  │    │Agent  │    │  Cockpit  │  │   Dockge   │
│Zero A │    │Zero B │    │  (d.)     │  │    (e.)    │
│ (a.)  │    │ (b.)  │    │           │  │            │
└───────┘    └───────┘    └───────────┘  └────────────┘
                   
┌──────────┐    ┌──────────────────────────────────────┐
│Agent     │    │         Ubuntu VPS Server            │
│Zero C    │    │  - Docker & Docker Compose           │
│ (c.)     │    │  - UFW Firewall (SSH only)           │
└──────────┘    │  - Cloudflared service               │
                │  - All services in containers        │
┌──────────┐    └──────────────────────────────────────┘
│FileBrowser│              
│  (f.)     │              
└───────────┘              
```

## Service URLs

After deployment, access your services at:

| Service | URL | Description | Default Credentials |
|---------|-----|-------------|---------------------|
| **Agent Zero (Primary)** | https://a.yourdomain.com | Primary AI coding agent | None |
| **Agent Zero (Secondary)** | https://b.yourdomain.com | Backup AI agent | None |
| **Agent Zero (Tertiary)** | https://c.yourdomain.com | Third AI agent | None |
| **Cockpit** | https://d.yourdomain.com | System administration | Your VPS user/password |
| **Dockge** | https://e.yourdomain.com | Container management | Set on first access |
| **FileBrowser** | https://f.yourdomain.com | File management | `admin` / `admin` ⚠️ |

⚠️ **Important**: Change the FileBrowser password immediately after first login!

## Configuration

### Domain and Services

Edit `modules/00-config.sh` to customize:

```bash
# Your domain
AXIOM_DOMAIN="yourdomain.com"

# Tunnel name
AXIOM_TUNNEL_NAME="axiom-tunnel"

# Agent Zero security
AZ_RFC_PASSWORD="ChangeThisPassword!"
```

See the [service configuration](modules/00-config.sh) file for all options.

### Adding New Services

Want to add more services? See the [Adding Services Guide](docs/adding-services.md).

## SSH Key Management

Axiom v1.1.0 offers flexible SSH key deployment:

### Method 1: Paste into Provider (Recommended)

1. Axiom generates or uses an existing SSH key
2. The public key is copied to your clipboard
3. You paste it into your VPS provider's control panel
4. Create your VPS with this key selected

**Supports**: OVH, Hetzner, DigitalOcean, Vultr, Linode, AWS, and more

### Method 2: Password Deployment

1. Axiom generates an SSH key
2. You provide your VPS password
3. Axiom connects via password SSH and installs the key

**Requirements**: Password authentication must be enabled on the VPS

## Deployment Modules

The deployment is organized into modular scripts:

| Module | Purpose | Key Features |
|--------|---------|--------------|
| `00-config.sh` | Configuration | Single source of truth, service registry |
| `lib.sh` | Shared library | Logging, container management, health checks |
| `01-system-prep.sh` | System preparation | Updates, conditional reboot |
| `02-core-platform.sh` | Core platform | Docker, essential packages |
| `03-cloudflare-tunnel.sh` | Tunnel setup | Automatic configuration from service registry |
| `04-firewall.sh` | Firewall | UFW lockdown, SSH only |
| `05-cockpit.sh` | Cockpit | System admin interface |
| `06-agent-zero.sh` | Agent Zero | Three AI agent instances |
| `07-dockge.sh` | Dockge | Container management UI |
| `08-filebrowser.sh` | FileBrowser | Web file manager |

Each module is idempotent and can be re-run safely.

## Security Features

- **No exposed ports**: All services behind Cloudflare Tunnel (except SSH)
- **UFW firewall**: Only SSH (port 22) is open
- **Automatic HTTPS**: Cloudflare provides SSL/TLS certificates
- **SSH key authentication**: No password-based SSH access
- **Container isolation**: Services run in separate containers
- **Environment-based secrets**: Sensitive data in environment variables

## Troubleshooting

### SSH Connection Fails

```powershell
# Test SSH connection manually
ssh -i %USERPROFILE%\.ssh\id_ed25519_vps_2026 ubuntu@YOUR_VPS_IP

# Check if key is correct
type %USERPROFILE%\.ssh\id_ed25519_vps_2026.pub
```

### Service Not Accessible

```bash
# On the VPS, check service status
docker ps

# Check specific service logs
docker logs agent-zero-core

# Verify tunnel is running
sudo systemctl status cloudflared

# View tunnel logs
sudo journalctl -u cloudflared -n 50
```

### Port Conflicts

```bash
# Find what's using a port
sudo netstat -tulpn | grep :5000

# Stop conflicting service
docker stop container-name
```

### Deployment Logs

All deployment operations are logged:

```bash
# View deployment log
sudo tail -f /var/log/axiom-deploy.log

# Search for errors
sudo grep ERROR /var/log/axiom-deploy.log
```

## Documentation

- **[Adding Services Guide](docs/adding-services.md)** - How to add custom services
- **[GitHub Beginner's Guide](docs/github-guide.md)** - Git basics for Axiom
- **[Configuration File](modules/00-config.sh)** - Heavily commented configuration

## System Requirements

### VPS Requirements
- **OS**: Ubuntu 20.04 or 22.04 LTS (Debian 11+ also works)
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 20GB minimum, 40GB recommended
- **CPU**: 1 core minimum, 2+ cores recommended

### Recommended VPS Providers
- **OVH Cloud** - Excellent value, European locations
- **Hetzner Cloud** - Great performance, European locations
- **DigitalOcean** - Easy to use, global locations
- **Vultr** - Good pricing, global locations
- **Linode** - Reliable, global locations

### Windows Requirements
- Windows 10 (build 1803+) or Windows 11
- PowerShell 5.1+ (built-in)
- Git for Windows
- OpenSSH Client (built-in or install via Optional Features)

## Development and Contributing

### Project Structure

```
.
├── axiom.cmd              # Windows batch launcher
├── axiom.ps1              # PowerShell deployment controller
├── modules/               # Deployment modules
│   ├── 00-config.sh      # Configuration
│   ├── lib.sh            # Shared library
│   ├── 01-system-prep.sh # System updates
│   ├── 02-core-platform.sh
│   ├── 03-cloudflare-tunnel.sh
│   ├── 04-firewall.sh
│   ├── 05-cockpit.sh
│   ├── 06-agent-zero.sh
│   ├── 07-dockge.sh
│   └── 08-filebrowser.sh
├── docs/                  # Documentation
│   ├── adding-services.md
│   └── github-guide.md
└── README.md             # This file
```

### Testing Changes

```bash
# Test individual modules on the VPS
sudo bash modules/05-cockpit.sh

# Check logs
sudo tail -f /var/log/axiom-deploy.log

# Verify services
docker ps
sudo systemctl status cloudflared
```

### Making Contributions

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test thoroughly on a fresh VPS
5. Commit: `git commit -m "Add my feature"`
6. Push: `git push origin feature/my-feature`
7. Open a Pull Request

## FAQ

**Q: Can I use this with a non-Ubuntu VPS?**  
A: The modules are written for Ubuntu/Debian. With modifications, it could work on CentOS/RHEL, but this is not currently supported.

**Q: Do I need to expose any ports through my VPS firewall?**  
A: Only SSH (port 22). All web services are accessed through the Cloudflare Tunnel.

**Q: What if I don't have a domain?**  
A: You need a domain for Cloudflare Tunnel. Free options include Freenom, or you can purchase one from Namecheap, Google Domains, etc.

**Q: Can I run this on my local machine?**  
A: It's designed for VPS deployment, but you could adapt it for local use. You'd need to modify the tunnel configuration and firewall rules.

**Q: How do I update Axiom?**  
A: `git pull` in the repository directory, then re-run `.\axiom.cmd` to deploy updates.

**Q: What if I want to remove everything?**  
A: Run this on the VPS to remove all containers and data:
```bash
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
sudo rm -rf /opt/stacks
sudo systemctl stop cloudflared
sudo systemctl disable cloudflared
```

**Q: Can I change the subdomains?**  
A: Yes, edit the `SERVICES` array in `modules/00-config.sh` and re-run module 03.

**Q: Is this production-ready?**  
A: Axiom is great for personal projects and development. For production, consider:
- Changing all default passwords
- Setting up proper backups
- Configuring monitoring
- Implementing proper secret management
- Setting up log rotation

## License

This project is provided as-is for personal and educational use.

## Support

- **Issues**: [GitHub Issues](https://github.com/w071278-hash/0/issues)
- **Discussions**: [GitHub Discussions](https://github.com/w071278-hash/0/discussions)
- **Documentation**: See `docs/` directory

## Changelog

### v1.1.0 (2026-02-13)
- ✨ Smart SSH key discovery and management
- ✨ Dual deployment methods (paste vs. password)
- ✨ 5 comprehensive pre-flight checks
- ✨ OS detection and IP configuration
- ✨ Enhanced user guidance throughout deployment
- 📚 Complete documentation overhaul
- 🔧 Improved error handling and troubleshooting
- 🎨 Better terminal output with colors and formatting

### v1.0.0 (Initial Release)
- 🚀 Initial deployment system
- 🐳 Docker and Docker Compose installation
- 🔐 Cloudflare Tunnel integration
- 🛡️ UFW firewall configuration
- 📦 Service deployments (Agent Zero, Cockpit, Dockge, FileBrowser)

---

Made with ❤️ for easy VPS deployment
