# Traefik Homelab Setup

A complete Traefik reverse proxy setup with Docker Compose for local services and Cloudflare Tunnels for external access.

## 🏗️ Architecture

- **Traefik**: Reverse proxy with automatic SSL certificates
- **Cloudflare Tunnel**: Secure external access without port forwarding
- **Services**: Jellyfin, qBittorrent, Radarr, Sonarr, Prowlarr
- **Network**: Docker network with Traefik-only access

## 🚀 Quick Start

```bash
# Clone and setup
git clone <your-repo>
cd traefik
cp env.example .env
# Edit .env with your Cloudflare credentials
./scripts/setup.sh
```

## 📁 Project Structure

```
traefik/
├── docker-compose.yml          # Main Traefik + Cloudflared
├── traefik.yml                 # Traefik static config
├── dynamic.yml                 # Traefik dynamic config
├── tunnel-config.yml           # Cloudflare tunnel config
├── Makefile                    # Easy management commands
├── scripts/                    # Management scripts
│   ├── setup.sh                # Initial setup script
│   ├── validate.sh             # Health check script
│   ├── tunnel.sh               # Tunnel management
│   ├── add-service.sh          # 🚀 Auto-add new services
│   ├── create-service.sh       # 📝 Create service templates
│   └── service-template.yml    # 📋 Service template
├── services/                   # Individual service configs
│   ├── jellyfin/
│   ├── qbittorrent/
│   ├── radarr/
│   ├── sonarr/
│   └── prowlarr/
└── cloudflared/                # Cloudflare certificates
```

## 🔧 Adding New Services (Simplified!)

### 🚀 **Quick Method (Recommended)**

#### 1. Create Service from Template
```bash
make create-service SERVICE_NAME=myapp
```
This creates:
- `services/myapp/docker-compose.yml` (from template)
- Automatically replaces placeholders with your service name

#### 2. Edit the Configuration
Edit `services/myapp/docker-compose.yml`:
- Update `image: your-image:latest` → `image: nginx:latest`
- Update `YOUR_PORT` → `80` (your actual service port)
- Update `/path/to/config` → `/mnt/data/myapp:/config`
- Add any additional environment variables or volumes

#### 3. Add Service Automatically
```bash
make add-service SERVICE_NAME=myapp
```
This automatically:
- ✅ Updates tunnel configuration
- ✅ Updates setup script
- ✅ Updates validation script  
- ✅ Updates Makefile
- ✅ Adds local DNS entry
- ✅ Creates Cloudflare DNS record
- ✅ Restarts tunnel and Traefik
- ✅ Starts your service

### 🔧 **Manual Method (Advanced Users)**

#### 1. Create Service Directory
```bash
mkdir -p services/your-service
```

### 2. Create docker-compose.yml
```yaml
version: "3.8"

services:
  your-service:
    image: your-image:latest
    container_name: your-service
    restart: unless-stopped
    networks:
      - traefik_net
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /path/to/config:/config
      # Add other volumes as needed
    labels:
      - "traefik.enable=true"
      
      # Local access
      - "traefik.http.routers.your-service.rule=Host(`your-service.local`)"
      - "traefik.http.routers.your-service.entrypoints=web"
      - "traefik.http.services.your-service.loadbalancer.server.port=YOUR_PORT"
      
      # External access via Cloudflare tunnel (HTTP)
      - "traefik.http.routers.your-service-external.rule=Host(`your-service.yourdomain.com`)"
      - "traefik.http.routers.your-service-external.entrypoints=web"
      
      # External access via Cloudflare (HTTPS)
      - "traefik.http.routers.your-service-secure.rule=Host(`your-service.yourdomain.com`)"
      - "traefik.http.routers.your-service-secure.entrypoints=websecure"
      - "traefik.http.routers.your-service-secure.tls.certresolver=cloudflare"

networks:
  traefik_net:
    external: true
```

### 3. Update Tunnel Configuration
Add to `tunnel-config.yml`:
```yaml
  - hostname: your-service.yourdomain.com
    service: http://YOUR_HOST_IP:80
    originRequest:
      httpHostHeader: your-service.yourdomain.com
```

### 4. Update Scripts
- Add DNS entry to `setup.sh`
- Add service to `validate.sh`
- Update access points in `setup.sh`

### 5. Add DNS Records
```bash
# Local DNS
echo "YOUR_IP  your-service.local" | sudo tee -a /etc/hosts

# Cloudflare DNS
cloudflared tunnel route dns homelab your-service.yourdomain.com
```

### 6. Restart Services
```bash
make restart-tunnel
make start your-service
```

## 🎯 Current Services

| Service | Port | Local URL | External URL | Purpose |
|---------|------|-----------|--------------|---------|
| **Traefik** | 80/443/8080 | `traefik.local:8080` | `traefik.groundcraft.xyz` | Reverse proxy & dashboard |
| **Jellyfin** | 8096 | `jellyfin.local` | `jellyfin.groundcraft.xyz` | Media server |
| **qBittorrent** | 8080 | `qbit.local` | `qbit.groundcraft.xyz` | Torrent client |
| **Radarr** | 7878 | `radarr.local` | `radarr.groundcraft.xyz` | Movie automation |
| **Sonarr** | 8989 | `sonarr.local` | `sonarr.groundcraft.xyz` | TV show automation |
| **Prowlarr** | 9696 | `prowlarr.local` | `prowlarr.groundcraft.xyz` | Indexer management |

## 🛠️ Management Commands

### Using Makefile (Recommended)
```bash
# Service management
make start all              # Start all services
make start traefik          # Start Traefik only
make start jellyfin         # Start specific service
make stop all               # Stop all services
make restart all            # Restart all services
make restart traefik        # Restart Traefik only
make restart jellyfin       # Restart specific service

# Tunnel management
make tunnel-start           # Start Cloudflare tunnel
make tunnel-stop            # Stop Cloudflare tunnel
make tunnel-restart         # Restart tunnel
make tunnel-status          # Check tunnel status
make tunnel-logs            # View tunnel logs

# Maintenance
make logs [service]         # View service logs
make status                 # Check all services status
make validate               # Run health checks
make clean                  # Clean up containers/networks
make update                 # Update all services

# Service Creation
make create-service SERVICE_NAME=myapp  # Create new service from template
make add-service SERVICE_NAME=myapp     # Integrate service with Traefik
make show-template                      # View service template
```

### Manual Commands
```bash
# Start services
docker compose up -d traefik
docker compose -f services/jellyfin/docker-compose.yml up -d
docker compose -f services/qbittorrent/docker-compose.yml up -d
docker compose -f services/radarr/docker-compose.yml up -d
docker compose -f services/sonarr/docker-compose.yml up -d
docker compose -f services/prowlarr/docker-compose.yml up -d

# Check status
./validate.sh

# Manage tunnel
./scripts/tunnel.sh start|stop|restart|status|logs
```

## 🔒 Security Features

- **Traefik-only access**: Services not directly exposed to host
- **Automatic SSL**: Cloudflare DNS challenge for certificates
- **Security headers**: CORS, XSS protection, etc.
- **Rate limiting**: Built-in protection against abuse
- **Authentication**: Basic auth for sensitive services

## 🌐 Access Points

### Local Network
- **Traefik Dashboard**: `http://traefik.local:8080`
- **Jellyfin**: `http://jellyfin.local`
- **qBittorrent**: `http://qbit.local`
- **Radarr**: `http://radarr.local`
- **Sonarr**: `http://sonarr.local`
- **Prowlarr**: `http://prowlarr.local`

### External Access
- **Jellyfin**: `https://jellyfin.groundcraft.xyz`
- **qBittorrent**: `https://qbit.groundcraft.xyz`
- **Radarr**: `https://radarr.groundcraft.xyz`
- **Sonarr**: `https://sonarr.groundcraft.xyz`
- **Prowlarr**: `https://prowlarr.groundcraft.xyz`

## 📋 Prerequisites

- Docker & Docker Compose
- Cloudflare account with domain
- Cloudflared client installed
- Port 80/443 available (for Traefik)

## 🔧 Configuration

### Environment Variables
Copy `env.example` to `.env` and configure:
```bash
CLOUDFLARE_API_TOKEN=your_api_token
CLOUDFLARE_EMAIL=your_email
DOMAIN=yourdomain.com
```

### Cloudflare Setup
1. Create API token with DNS edit permissions
2. Create tunnel in Cloudflare dashboard
3. Download tunnel credentials
4. Place in `cloudflared/` directory

## 🚨 Important Notes

- **Always restart Traefik** when adding/modifying services
- **Restart tunnel** after updating tunnel configuration
- **Check logs** if services aren't accessible
- **Validate setup** after any changes using `make validate`

## 🆘 Troubleshooting

### Common Issues
1. **Service not accessible**: Check if Traefik is running
2. **External access fails**: Verify tunnel is running and DNS is correct
3. **SSL errors**: Check Cloudflare certificate configuration
4. **Port conflicts**: Ensure no other services use ports 80/443/8080

### Debug Commands
```bash
make logs traefik           # Check Traefik logs
make tunnel-logs            # Check tunnel logs
make status                 # Check all services
docker network inspect traefik_net  # Check network
```

## 📚 Additional Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Docker Compose](https://docs.docker.com/compose/)
