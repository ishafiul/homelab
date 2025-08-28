# Traefik Homelab Setup

Complete Traefik configuration for local services with Cloudflare integration and external access without port forwarding.

## 🚀 Quick Start

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```

2. **Configure environment:**
   ```bash
   cp env.example .env
   # Edit .env with your Cloudflare credentials
   ```

3. **Start Traefik:**
   ```bash
   docker-compose up -d
   ```

## 📁 Project Structure

```
traefik/
├── docker-compose.yml          # Main Traefik container
├── traefik.yml                 # Static configuration
├── dynamic.yml                 # Dynamic configuration
├── tunnel-config.yml           # Cloudflare tunnel config
├── env.example                 # Environment variables template
├── setup.sh                    # Automated setup script
├── services/
│   ├── jellyfin/
│   │   └── docker-compose.yml  # Jellyfin service
│   └── qbittorrent/
│       └── docker-compose.yml  # qBittorrent service
├── certs/                      # SSL certificates
├── logs/                       # Traefik logs
└── cloudflared/               # Tunnel credentials
```

## 🔧 Configuration

### Environment Variables (.env)

```bash
CF_API_EMAIL=your-email@example.com
CF_DNS_API_TOKEN=your-cloudflare-api-token
DOMAIN=groundcraft.xyz
PUID=1000
PGID=1000
MEDIA_PATH=/path/to/media
DOWNLOADS_PATH=/path/to/downloads
```

### Cloudflare API Token

Create a Cloudflare API token with these permissions:
- Zone:Zone:Read
- Zone:DNS:Edit

## 🌐 Access Points

### Local Access (Traefik-only)
- Traefik Dashboard: http://traefik.local:8080
- Jellyfin: http://jellyfin.local (no direct port 8096)
- qBittorrent: http://qbit.local (no direct port 8081)

### External Access (via Cloudflare Tunnel)
- Jellyfin: https://jellyfin.groundcraft.xyz
- qBittorrent: https://qbit.groundcraft.xyz
- Traefik: https://traefik.groundcraft.xyz

### Security Benefits
- ✅ No direct service port exposure
- ✅ All traffic routed through Traefik
- ✅ Centralized SSL termination
- ✅ Better firewall posture

## 🛠️ Service Management

### Start services:
```bash
# Start Traefik
docker compose up -d traefik

# Start media services
docker compose -f services/jellyfin/docker-compose.yml up -d
docker compose -f services/qbittorrent/docker-compose.yml up -d
```

### Tunnel management:
```bash
# Start tunnel
./tunnel.sh start

# Check status
./tunnel.sh status

# View logs
./tunnel.sh logs

# Stop tunnel
./tunnel.sh stop
```

### View logs:
```bash
docker compose logs traefik
tail -f cloudflared.log
```

### Stop services:
```bash
docker compose down
docker compose -f services/jellyfin/docker-compose.yml down
docker compose -f services/qbittorrent/docker-compose.yml down
./tunnel.sh stop
```

## 🔒 Security Features

- Automatic HTTPS with Let's Encrypt + Cloudflare DNS
- Security headers middleware
- Rate limiting
- Basic authentication for sensitive services
- TLS 1.2+ with strong cipher suites

## 🌍 Cloudflare Tunnel Setup

1. **Install cloudflared:**
   ```bash
   curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   sudo dpkg -i cloudflared.deb
   ```

2. **Authenticate:**
   ```bash
   cloudflared tunnel login
   ```

3. **Create tunnel:**
   ```bash
   cloudflared tunnel create homelab
   ```

4. **Copy credentials:**
   ```bash
   cp ~/.cloudflared/[tunnel-id].json ./cloudflared/
   ```

5. **Update tunnel-config.yml** with your tunnel name and credentials file

6. **Create DNS records** in Cloudflare dashboard pointing to your tunnel

7. **Start tunnel:**
   ```bash
   docker-compose up -d cloudflared
   ```

## 📝 Adding New Services

1. Create service directory in `services/`
2. Add docker-compose.yml with Traefik labels:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.myservice.rule=Host(`myservice.local`)"
     - "traefik.http.routers.myservice.entrypoints=web"
     - "traefik.http.services.myservice.loadbalancer.server.port=8080"
   ```
3. Add to tunnel-config.yml for external access
4. Update /etc/hosts for local access

## 🔍 Troubleshooting

### Check service status:
```bash
docker-compose ps
```

### View Traefik logs:
```bash
docker-compose logs traefik
```

### Test connectivity:
```bash
curl -H "Host: jellyfin.local" http://localhost
```

### Validate certificates:
```bash
docker-compose exec traefik cat /certs/acme.json
```

## 📊 Monitoring

Traefik includes Prometheus metrics on `:8080/metrics` for monitoring integration.

## 🤝 Support

Check logs first, then verify:
1. Docker network exists: `docker network ls | grep traefik_net`
2. DNS resolution: `nslookup jellyfin.local`
3. Cloudflare token permissions
4. Service port mappings in docker-compose files
