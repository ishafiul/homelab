#!/bin/bash

# Traefik Homelab Setup Script
set -e

echo "🚀 Setting up Traefik homelab environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

print_success "Docker is installed and running"

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

# Determine which Docker Compose command to use
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

print_success "Docker Compose is available ($DOCKER_COMPOSE)"

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p certs logs cloudflared
chmod 755 certs logs cloudflared

# Set proper permissions for ACME certificates
touch certs/acme.json
chmod 600 certs/acme.json

print_success "Created directories: certs, logs, cloudflared"

# Create Docker network
print_status "Creating Docker network..."
if ! docker network ls | grep -q traefik_net; then
    docker network create traefik_net
    print_success "Created traefik_net network"
else
    print_warning "traefik_net network already exists"
fi

# Check for environment file
if [ ! -f .env ]; then
    print_warning ".env file not found. Please copy env.example to .env and configure it."
    print_status "Creating .env from env.example..."
    cp env.example .env
    print_warning "Please edit .env file with your Cloudflare credentials and domain before continuing."
    
    echo
    print_status "Required configuration:"
    echo "1. Set CF_API_EMAIL to your Cloudflare email"
    echo "2. Set CF_DNS_API_TOKEN to your Cloudflare API token"
    echo "3. Set DOMAIN to your domain name"
    echo "4. Update MEDIA_PATH and DOWNLOADS_PATH to your actual paths"
    echo
    
    read -p "Have you configured your .env file? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Please configure .env file and run this script again."
        exit 1
    fi
fi

print_success "Environment file exists"

# Add local DNS entries
print_status "Adding local DNS entries to /etc/hosts..."
LOCAL_IP=$(hostname -I | awk '{print $1}')

if ! grep -q "traefik.local" /etc/hosts; then
    echo "# Traefik Local Services" | sudo tee -a /etc/hosts
    echo "$LOCAL_IP  traefik.local" | sudo tee -a /etc/hosts
    echo "$LOCAL_IP  jellyfin.local" | sudo tee -a /etc/hosts
    echo "$LOCAL_IP  qbit.local" | sudo tee -a /etc/hosts
    echo "$LOCAL_IP  radarr.local" | sudo tee -a /etc/hosts
    echo "$LOCAL_IP  sonarr.local" | sudo tee -a /etc/hosts
    echo "$LOCAL_IP  prowlarr.local" | sudo tee -a /etc/hosts
    print_success "Added local DNS entries"
    echo "$LOCAL_IP  testapp.local" | sudo tee -a /etc/hosts
else
    print_warning "Local DNS entries already exist in /etc/hosts"
fi

# Start Traefik
print_status "Starting Traefik..."
$DOCKER_COMPOSE up -d traefik

# Wait for Traefik to be ready
print_status "Waiting for Traefik to be ready..."
sleep 10

# Check if Traefik is running
if docker ps | grep -q traefik; then
    print_success "Traefik is running!"
    echo
    
    # Check for optimized setup (no direct port exposures)
    if docker ps --format "{{.Ports}}" | grep -q "8096\|8081"; then
        print_warning "Services have direct port access - not optimized for Traefik-only"
        echo "Consider removing port mappings for better security"
    else
        print_success "Optimized setup detected - services use Traefik-only access"
    fi
    
    print_status "Access points:"
    echo "🌐 Traefik Dashboard: http://traefik.local:8080"
    echo "📊 Local Services (Traefik-only access):"
    echo "   - Jellyfin: http://jellyfin.local (no direct port access)"
    echo "   - qBittorrent: http://qbit.local (no direct port access)"
    echo "   - Radarr: http://radarr.local (no direct port access)"
    echo "   - Sonarr: http://sonarr.local (no direct port access)"
    echo "   - Prowlarr: http://prowlarr.local (no direct port access)"
    echo "   - External: https://jellyfin.groundcraft.xyz, https://qbit.groundcraft.xyz, https://radarr.groundcraft.xyz, https://sonarr.groundcraft.xyz, https://prowlarr.groundcraft.xyz, https://testapp.groundcraft.xyz
   - testapp: http://testapp.local (no direct port access)
    echo
else
    print_error "Traefik failed to start. Check logs with: $DOCKER_COMPOSE logs traefik"
    exit 1
fi

# Cloudflare Tunnel setup instructions
echo
print_status "📋 Next Steps for Cloudflare Tunnel Setup:"
echo
echo "1. Install cloudflared:"
echo "   curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
echo "   sudo dpkg -i cloudflared.deb"
echo
echo "2. Authenticate with Cloudflare:"
echo "   cloudflared tunnel login"
echo
echo "3. Create a tunnel:"
echo "   cloudflared tunnel create homelab"
echo
echo "4. Copy the credentials file to ./cloudflared/"
echo "   cp ~/.cloudflared/[tunnel-id].json ./cloudflared/"
echo
echo "5. Update tunnel-config.yml with your tunnel name and credentials file"
echo
echo "6. Create DNS records in Cloudflare for your services"
echo
echo "7. Start the tunnel:"
echo "   nohup cloudflared tunnel --config ./tunnel-config.yml run > cloudflared.log 2>&1 &"
echo "   (Note: Tunnel runs on host, not in Docker container)"
echo
print_status "📝 Service Management:"
echo "Start Traefik:         $DOCKER_COMPOSE up -d traefik"
echo "Start Jellyfin:        $DOCKER_COMPOSE -f services/jellyfin/docker-compose.yml up -d"
echo "Start qBittorrent:     $DOCKER_COMPOSE -f services/qbittorrent/docker-compose.yml up -d"
echo "Start Radarr:          $DOCKER_COMPOSE -f services/radarr/docker-compose.yml up -d"
echo "Start Sonarr:          $DOCKER_COMPOSE -f services/sonarr/docker-compose.yml up -d"
echo "Start Prowlarr:        $DOCKER_COMPOSE -f services/prowlarr/docker-compose.yml up -d"
echo "View logs:             $DOCKER_COMPOSE logs [service-name]"
echo "Start testapp:          $DOCKER_COMPOSE -f services/testapp/docker-compose.yml up -d"
echo "Stop all services:     $DOCKER_COMPOSE down && $DOCKER_COMPOSE -f services/*/docker-compose.yml down"
echo "Tunnel status:         ps aux | grep cloudflared"
echo "Stop tunnel:           pkill cloudflared"
echo

# Offer to start services
echo
read -p "Would you like to start Jellyfin and qBittorrent services now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Starting services..."
    $DOCKER_COMPOSE -f services/jellyfin/docker-compose.yml up -d || print_warning "Jellyfin failed to start (check config paths)"
    $DOCKER_COMPOSE -f services/qbittorrent/docker-compose.yml up -d || print_warning "qBittorrent failed to start (check config paths)"
    sleep 5
    print_success "Services started! Check http://jellyfin.local and http://qbit.local"
fi

echo
print_success "🎉 Traefik setup completed! Check the access points above."
print_status "📋 Next: Update media/download paths in service configs and set up Cloudflare tunnel for external access."
