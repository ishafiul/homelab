#!/bin/bash

# Automated Service Addition Script for Traefik Homelab
# This script reads docker-compose.yml files and automatically updates all configurations

set -e

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

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES_DIR="$PROJECT_ROOT/services"
TUNNEL_CONFIG="$PROJECT_ROOT/tunnel-config.yml"
SETUP_SCRIPT="$PROJECT_ROOT/scripts/setup.sh"
VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate.sh"
MAKEFILE="$PROJECT_ROOT/Makefile"
HOSTS_FILE="/etc/hosts"
DOMAIN="groundcraft.xyz"

# Function to get local IP
get_local_ip() {
    hostname -I | awk '{print $1}'
}

# Function to extract service info from docker-compose.yml
extract_service_info() {
    local service_dir="$1"
    local compose_file="$service_dir/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        print_error "Docker compose file not found: $compose_file"
        return 1
    fi
    
    # Extract service name from directory
    local service_name=$(basename "$service_dir")
    
    # Extract container name
    local container_name=$(grep -A1 "container_name:" "$compose_file" | grep -v "container_name:" | xargs)
    
    # Extract port from Traefik labels
    local port=$(grep "loadbalancer.server.port" "$compose_file" | sed 's/.*port=\([0-9]*\).*/\1/' | head -1)
    
    # If no port found, use default 8080
    if [[ -z "$port" ]]; then
        port="8080"
    fi
    
    # Extract image
    local image=$(grep "image:" "$compose_file" | head -1 | sed 's/.*image: *//')
    
    echo "$service_name|$container_name|$port|$image"
}

# Function to update tunnel configuration
update_tunnel_config() {
    local service_name="$1"
    local local_ip="$2"
    
    print_status "Updating tunnel configuration for $service_name..."
    
    # Check if service already exists in tunnel config
    if grep -q "hostname: $service_name.$DOMAIN" "$TUNNEL_CONFIG"; then
        print_warning "Service $service_name already exists in tunnel config"
        return 0
    fi
    
    # Add service to tunnel config before the catch-all rule
    local temp_file=$(mktemp)
    local catch_all_line=$(grep -n "service: http_status:404" "$TUNNEL_CONFIG" | cut -d: -f1)
    
    if [[ -n "$catch_all_line" ]]; then
        # Insert before catch-all rule
        head -n $((catch_all_line - 1)) "$TUNNEL_CONFIG" > "$temp_file"
        cat >> "$temp_file" << EOF
  - hostname: $service_name.$DOMAIN
    service: http://$local_ip:80
    originRequest:
      httpHostHeader: $service_name.$DOMAIN
      
EOF
        tail -n +$catch_all_line "$TUNNEL_CONFIG" >> "$temp_file"
        mv "$temp_file" "$TUNNEL_CONFIG"
    else
        print_error "Could not find catch-all rule in tunnel config"
        return 1
    fi
    
    print_success "Tunnel configuration updated for $service_name"
}

# Function to update setup script
update_setup_script() {
    local service_name="$1"
    local local_ip="$2"
    
    print_status "Updating setup script for $service_name..."
    
    # Check if service already exists in setup script
    if grep -q "$service_name.local" "$SETUP_SCRIPT"; then
        print_warning "Service $service_name already exists in setup script"
        return 0
    fi
    
    # Add DNS entry to setup script
    local dns_line="    echo \"\$LOCAL_IP  $service_name.local\" | sudo tee -a /etc/hosts"
    local last_dns_line=$(grep -n "echo.*\.local.*tee -a /etc/hosts" "$SETUP_SCRIPT" | tail -1 | cut -d: -f1)
    
    if [[ -n "$last_dns_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_dns_line + 1)) "$SETUP_SCRIPT" > "$temp_file"
        echo "$dns_line" >> "$temp_file"
        tail -n +$((last_dns_line + 2)) "$SETUP_SCRIPT" >> "$temp_file"
        mv "$temp_file" "$SETUP_SCRIPT"
    else
        print_error "Could not find DNS section in setup script"
        return 1
    fi
    
    # Add service to access points
    local access_line="   - $service_name: http://$service_name.local (no direct port access)"
    local last_access_line=$(grep -n "no direct port access" "$SETUP_SCRIPT" | tail -1 | cut -d: -f1)
    
    if [[ -n "$last_access_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_access_line + 1)) "$SETUP_SCRIPT" > "$temp_file"
        echo "$access_line" >> "$temp_file"
        tail -n +$((last_access_line + 2)) "$SETUP_SCRIPT" >> "$temp_file"
        mv "$temp_file" "$SETUP_SCRIPT"
    fi
    
    # Add external access
    local external_line="   - External: https://jellyfin.$DOMAIN, https://qbit.$DOMAIN, https://radarr.$DOMAIN, https://sonarr.$DOMAIN, https://prowlarr.$DOMAIN, https://$service_name.$DOMAIN"
    sed -i "s|   - External:.*|$external_line|" "$SETUP_SCRIPT"
    
    # Add service management command
    local cmd_line="echo \"Start $service_name:          \$DOCKER_COMPOSE -f services/$service_name/docker-compose.yml up -d\""
    local last_cmd_line=$(grep -n "Start.*docker-compose.yml up -d" "$SETUP_SCRIPT" | tail -1 | cut -d: -f1)
    
    if [[ -n "$last_cmd_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_cmd_line + 1)) "$SETUP_SCRIPT" > "$temp_file"
        echo "$cmd_line" >> "$temp_file"
        tail -n +$((last_cmd_line + 2)) "$SETUP_SCRIPT" >> "$temp_file"
        mv "$temp_file" "$SETUP_SCRIPT"
    fi
    
    print_success "Setup script updated for $service_name"
}

# Function to update validation script
update_validation_script() {
    local service_name="$1"
    
    print_status "Updating validation script for $service_name..."
    
    # Check if service already exists in validation script
    if grep -q "$service_name" "$VALIDATE_SCRIPT"; then
        print_warning "Service $service_name already exists in validation script"
        return 0
    fi
    
    # Add container status check
    local status_check="if docker ps | grep -q $service_name; then\n    print_check \"$service_name container is running\"\nelse\n    print_warn \"$service_name container is not running\"\nfi"
    local last_status_line=$(grep -n "container is running" "$VALIDATE_SCRIPT" | tail -1 | cut -d: -f1)
    
    if [[ -n "$last_status_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_status_line + 3)) "$VALIDATE_SCRIPT" > "$temp_file"
        echo "" >> "$temp_file"
        echo "$status_check" >> "$temp_file"
        tail -n +$((last_status_line + 4)) "$VALIDATE_SCRIPT" >> "$temp_file"
        mv "$temp_file" "$VALIDATE_SCRIPT"
    fi
    
    # Add accessibility check
    local access_check="if curl -s -I http://192.168.0.102:80 -H \"Host: $service_name.local\" | grep -q \"HTTP/1.1 200\\|HTTP/1.1 401\"; then\n    print_check \"$service_name accessible via Traefik\"\nelse\n    print_warn \"$service_name not accessible via Traefik (may not be started)\"\nfi"
    local last_access_line=$(grep -n "accessible via Traefik" "$VALIDATE_SCRIPT" | tail -1 | cut -d: -f1)
    
    if [[ -n "$last_access_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_access_line + 3)) "$VALIDATE_SCRIPT" > "$temp_file"
        echo "" >> "$temp_file"
        echo "$access_check" >> "$temp_file"
        tail -n +$((last_access_line + 4)) "$VALIDATE_SCRIPT" >> "$temp_file"
        mv "$temp_file" "$VALIDATE_SCRIPT"
    fi
    
    # Update next steps
    sed -i "s|• Access services:.*|• Access services: http://jellyfin.local, http://qbit.local, http://radarr.local, http://sonarr.local, http://prowlarr.local, and http://$service_name.local|" "$VALIDATE_SCRIPT"
    
    print_success "Validation script updated for $service_name"
}

# Function to update Makefile
update_makefile() {
    local service_name="$1"
    
    print_status "Updating Makefile for $service_name..."
    
    # Check if service already exists in Makefile
    if grep -q "$service_name" "$MAKEFILE"; then
        print_warning "Service $service_name already exists in Makefile"
        return 0
    fi
    
    # Add service to SERVICES variable
    sed -i "s|SERVICES := traefik.*|SERVICES := traefik jellyfin qbittorrent radarr sonarr prowlarr $service_name|" "$MAKEFILE"
    
    # Add start service function
    local start_func="start-$service_name:\n\t@echo \"🚀 Starting $service_name...\"\n\t@docker compose -f \$(SERVICE_DIR)/$service_name/docker-compose.yml up -d\n\t@echo \"✅ $service_name started!\""
    local last_start_line=$(grep -n "start-prowlarr:" "$MAKEFILE" | cut -d: -f1)
    
    if [[ -n "$last_start_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_start_line + 3)) "$MAKEFILE" > "$temp_file"
        echo "" >> "$temp_file"
        echo "$start_func" >> "$temp_file"
        tail -n +$((last_start_line + 4)) "$MAKEFILE" >> "$temp_file"
        mv "$temp_file" "$MAKEFILE"
    fi
    
    # Add stop service function
    local stop_func="stop-$service_name:\n\t@echo \"🛑 Stopping $service_name...\"\n\t@docker compose -f \$(SERVICE_DIR)/$service_name/docker-compose.yml down\n\t@echo \"✅ $service_name stopped!\""
    local last_stop_line=$(grep -n "stop-prowlarr:" "$MAKEFILE" | cut -d: -f1)
    
    if [[ -n "$last_stop_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_stop_line + 3)) "$MAKEFILE" > "$temp_file"
        echo "" >> "$temp_file"
        echo "$stop_func" >> "$temp_file"
        tail -n +$((last_stop_line + 4)) "$MAKEFILE" >> "$temp_file"
        mv "$temp_file" "$MAKEFILE"
    fi
    
    # Add restart service function
    local restart_func="restart-$service_name:\n\t@echo \"🔄 Restarting $service_name + Traefik...\"\n\t@docker compose -f \$(SERVICE_DIR)/$service_name/docker-compose.yml down\n\t@docker compose -f \$(SERVICE_DIR)/$service_name/docker-compose.yml up -d\n\t@docker compose -f \$(MAIN_COMPOSE) restart traefik\n\t@echo \"✅ $service_name + Traefik restarted!\""
    local last_restart_line=$(grep -n "restart-prowlarr:" "$MAKEFILE" | cut -d: -f1)
    
    if [[ -n "$last_restart_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_restart_line + 3)) "$MAKEFILE" > "$temp_file"
        echo "" >> "$temp_file"
        echo "$restart_func" >> "$temp_file"
        tail -n +$((last_restart_line + 4)) "$MAKEFILE" >> "$temp_file"
        mv "$temp_file" "$MAKEFILE"
    fi
    
    # Add quick access alias
    local alias_line="$service_name: start-$service_name"
    local last_alias_line=$(grep -n "prowlarr: start-prowlarr" "$MAKEFILE" | cut -d: -f1)
    
    if [[ -n "$last_alias_line" ]]; then
        local temp_file=$(mktemp)
        head -n $((last_alias_line + 1)) "$MAKEFILE" > "$temp_file"
        echo "$alias_line" >> "$temp_file"
        tail -n +$((last_alias_line + 2)) "$MAKEFILE" >> "$temp_file"
        mv "$temp_file" "$MAKEFILE"
    fi
    
    print_success "Makefile updated for $service_name"
}

# Function to add local DNS entry
add_local_dns() {
    local service_name="$1"
    local local_ip="$2"
    
    print_status "Adding local DNS entry for $service_name..."
    
    if grep -q "$service_name.local" "$HOSTS_FILE"; then
        print_warning "DNS entry for $service_name.local already exists"
        return 0
    fi
    
    echo "$local_ip  $service_name.local" | sudo tee -a "$HOSTS_FILE"
    print_success "Local DNS entry added for $service_name.local"
}

# Function to create Cloudflare DNS record
create_cloudflare_dns() {
    local service_name="$1"
    
    print_status "Creating Cloudflare DNS record for $service_name.$DOMAIN..."
    
    # Check if cloudflared is available
    if ! command -v cloudflared &> /dev/null; then
        print_warning "cloudflared not found. Please create DNS record manually:"
        print_warning "  - Add CNAME record: $service_name.$DOMAIN -> your-tunnel-id"
        return 0
    fi
    
    # Create DNS record
    if cloudflared tunnel route dns homelab "$service_name.$DOMAIN"; then
        print_success "Cloudflare DNS record created for $service_name.$DOMAIN"
    else
        print_warning "Failed to create DNS record. Please create manually:"
        print_warning "  - Add CNAME record: $service_name.$DOMAIN -> your-tunnel-id"
    fi
}

# Function to restart tunnel
restart_tunnel() {
    print_status "Restarting Cloudflare tunnel to apply new configuration..."
    
    if [[ -f "$PROJECT_ROOT/scripts/tunnel.sh" ]]; then
        "$PROJECT_ROOT/scripts/tunnel.sh" restart
        print_success "Tunnel restarted"
    else
        print_warning "Tunnel script not found. Please restart tunnel manually."
    fi
}

# Function to start service
start_service() {
    local service_name="$1"
    local service_dir="$SERVICES_DIR/$service_name"
    
    print_status "Starting $service_name service..."
    
    if [[ -d "$service_dir" ]]; then
        cd "$service_dir"
        if docker compose up -d; then
            print_success "$service_name service started successfully"
        else
            print_error "Failed to start $service_name service"
            return 1
        fi
        cd "$PROJECT_ROOT"
    else
        print_error "Service directory not found: $service_dir"
        return 1
    fi
}

# Function to restart Traefik
restart_traefik() {
    print_status "Restarting Traefik to discover new service..."
    
    if docker compose restart traefik; then
        print_success "Traefik restarted successfully"
    else
        print_error "Failed to restart Traefik"
        return 1
    fi
}

# Main function
main() {
    local service_name="$1"
    
    if [[ -z "$service_name" ]]; then
        print_error "Usage: $0 <service-name>"
        print_error "Example: $0 myapp"
        exit 1
    fi
    
    local service_dir="$SERVICES_DIR/$service_name"
    
    if [[ ! -d "$service_dir" ]]; then
        print_error "Service directory not found: $service_dir"
        print_error "Please create the service directory and docker-compose.yml first"
        exit 1
    fi
    
    if [[ ! -f "$service_dir/docker-compose.yml" ]]; then
        print_error "Docker compose file not found: $service_dir/docker-compose.yml"
        print_error "Please create the docker-compose.yml file first"
        exit 1
    fi
    
    print_status "Adding service: $service_name"
    print_status "Service directory: $service_dir"
    
    # Extract service information
    local service_info=$(extract_service_info "$service_dir")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    IFS='|' read -r service_name container_name port image <<< "$service_info"
    
    print_status "Service details:"
    print_status "  - Name: $service_name"
    print_status "  - Container: $container_name"
    print_status "  - Port: $port"
    print_status "  - Image: $image"
    
    # Get local IP
    local local_ip=$(get_local_ip)
    print_status "Local IP: $local_ip"
    
    # Update all configurations
    update_tunnel_config "$service_name" "$local_ip"
    update_setup_script "$service_name" "$local_ip"
    update_validation_script "$service_name"
    update_makefile "$service_name"
    add_local_dns "$service_name" "$local_ip"
    create_cloudflare_dns "$service_name"
    
    # Restart services
    restart_tunnel
    start_service "$service_name"
    restart_traefik
    
    print_success "🎉 Service $service_name added successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Access your service at: http://$service_name.local"
    print_status "2. External access: https://$service_name.$DOMAIN"
    print_status "3. Use 'make restart $service_name' to restart with Traefik"
    print_status "4. Run 'make validate' to check everything is working"
}

# Run main function with all arguments
main "$@"
