#!/bin/bash

# Traefik Setup Validation Script
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }
print_check() { echo -e "${GREEN}✅${NC} $1"; }
print_fail() { echo -e "${RED}❌${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }

echo "🔍 Validating Traefik Setup..."
echo

# Check Docker
print_header "Docker Status"
if docker info &> /dev/null; then
    print_check "Docker is running"
else
    print_fail "Docker is not running"
    exit 1
fi

# Check containers
print_header "Container Status"
if docker ps | grep -q traefik; then
    print_check "Traefik container is running"
else
    print_fail "Traefik container is not running"
fi

if docker ps | grep -q jellyfin; then
    print_check "Jellyfin container is running"
else
    print_warn "Jellyfin container is not running"
fi

if docker ps | grep -q qbittorrent; then
    print_check "qBittorrent container is running"
else
    print_warn "qBittorrent container is not running"
fi

if docker ps | grep -q radarr; then
    print_check "Radarr container is running"
else
    print_warn "Radarr container is not running"
fi

if docker ps | grep -q sonarr; then
    print_check "Sonarr container is running"
else
    print_warn "Sonarr container is not running"
fi

if docker ps | grep -q prowlarr; then
    print_check "Prowlarr container is running"
else
    print_warn "Prowlarr container is not running"
fi

if docker ps | grep -q testapp; then\n    print_check "testapp container is running"\nelse\n    print_warn "testapp container is not running"\nfi

# Check optimization
print_header "Security Optimization"
if docker ps --format "{{.Ports}}" | grep -q "0.0.0.0:8096\|0.0.0.0:8081"; then
    print_fail "Services have direct port access (not optimized)"
    echo "Consider removing port mappings: 8096:8096 and 8081:8080"
else
    print_check "Optimized: Services use Traefik-only access"
    echo "Services expose only internal ports (8096/tcp, 8080/tcp) - accessible only via Traefik"
fi

# Check network
print_header "Network Configuration"
if docker network ls | grep -q traefik_net; then
    print_check "traefik_net network exists"
else
    print_fail "traefik_net network missing"
fi

# Check local access
print_header "Local Access Test"
if curl -s -I http://192.168.0.102:8080 | grep -q "HTTP/1.1 308\|HTTP/1.1 200"; then
    print_check "Traefik dashboard accessible"
else
    print_fail "Traefik dashboard not accessible"
fi

if curl -s -I http://192.168.0.102:80 -H "Host: jellyfin.local" | grep -q "HTTP/1.1 302\|HTTP/1.1 200"; then
    print_check "Jellyfin accessible via Traefik"
else
    print_warn "Jellyfin not accessible via Traefik (may not be started)"
fi

if curl -s -I http://192.168.0.102:80 -H "Host: qbit.local" | grep -q "HTTP/1.1 200"; then
    print_check "qBittorrent accessible via Traefik"
else
    print_warn "qBittorrent not accessible via Traefik (may not be started)"
fi

if curl -s -I http://192.168.0.102:80 -H "Host: radarr.local" | grep -q "HTTP/1.1 200\|HTTP/1.1 401"; then
    print_check "Radarr accessible via Traefik"
else
    print_warn "Radarr not accessible via Traefik (may not be started)"
fi

if curl -s -I http://192.168.0.102:80 -H "Host: sonarr.local" | grep -q "HTTP/1.1 200\|HTTP/1.1 401"; then
    print_check "Sonarr accessible via Traefik"
else
    print_warn "Sonarr not accessible via Traefik (may not be started)"
fi

if curl -s -I http://192.168.0.102:80 -H "Host: prowlarr.local" | grep -q "HTTP/1.1 200\|HTTP/1.1 401"; then
    print_check "Prowlarr accessible via Traefik"
else
    print_warn "Prowlarr not accessible via Traefik (may not be started)"
fi

# Check tunnel

if curl -s -I http://192.168.0.102:80 -H "Host: testapp.local" | grep -q "HTTP/1.1 200\|HTTP/1.1 401"; then\n    print_check "testapp accessible via Traefik"\nelse\n    print_warn "testapp not accessible via Traefik (may not be started)"\nfi
print_header "Cloudflare Tunnel"
if pgrep -f "cloudflared tunnel" > /dev/null; then
    print_check "Cloudflare tunnel is running"
else
    print_warn "Cloudflare tunnel is not running"
fi

# Check external access
print_header "External Access Test"
if curl -s -I https://jellyfin.groundcraft.xyz | grep -q "HTTP/2 302\|HTTP/2 200"; then
    print_check "External Jellyfin access working"
else
    print_warn "External Jellyfin access not working (check tunnel/DNS)"
fi

if curl -s -I https://qbit.groundcraft.xyz | grep -q "HTTP/2 200"; then
    print_check "External qBittorrent access working"
else
    print_warn "External qBittorrent access not working (check tunnel/DNS)"
fi

echo
echo "🎉 Validation complete!"
echo
echo "Next steps:"
echo "• Update media paths in services/jellyfin/docker-compose.yml"
echo "• Update download paths in services/qbittorrent/docker-compose.yml"
echo "• Access services: http://jellyfin.local, http://qbit.local, http://radarr.local, http://sonarr.local, http://prowlarr.local, and http://testapp.local
