#!/bin/bash

# Service Creation Helper Script
# This script helps create new service directories and files

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
TEMPLATE_FILE="$PROJECT_ROOT/scripts/service-template.yml"

# Function to create service directory and files
create_service() {
    local service_name="$1"
    local service_dir="$SERVICES_DIR/$service_name"
    
    if [[ -d "$service_dir" ]]; then
        print_warning "Service directory already exists: $service_dir"
        return 1
    fi
    
    print_status "Creating service directory: $service_dir"
    mkdir -p "$service_dir"
    
    print_status "Creating docker-compose.yml from template..."
    cp "$TEMPLATE_FILE" "$service_dir/docker-compose.yml"
    
    # Replace placeholders in the template
    sed -i "s/your-service-name/$service_name/g" "$service_dir/docker-compose.yml"
    sed -i "s/your-image:latest/your-image:latest/g" "$service_dir/docker-compose.yml"
    sed -i "s/YOUR_PORT/8080/g" "$service_dir/docker-compose.yml"
    sed -i "s/yourdomain.com/groundcraft.xyz/g" "$service_dir/docker-compose.yml"
    
    print_success "Service directory created: $service_dir"
    print_success "Docker compose file created: $service_dir/docker-compose.yml"
    
    print_status ""
    print_status "Next steps:"
    print_status "1. Edit $service_dir/docker-compose.yml with your specific configuration"
    print_status "2. Update the image, port, volumes, and environment variables"
    print_status "3. Run: ./scripts/add-service.sh $service_name"
    print_status ""
    print_status "Template placeholders to replace:"
    print_status "  - your-image:latest -> your actual image"
    print_status "  - YOUR_PORT -> your service port"
    print_status "  - /path/to/config -> your actual config path"
    print_status "  - Add any additional environment variables or volumes"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <service-name>"
    echo ""
    echo "This script creates a new service directory with a template docker-compose.yml file."
    echo ""
    echo "Example:"
    echo "  $0 myapp"
    echo ""
    echo "This will create:"
    echo "  services/myapp/docker-compose.yml"
    echo ""
    echo "After editing the file, run:"
    echo "  ./scripts/add-service.sh myapp"
}

# Main function
main() {
    local service_name="$1"
    
    if [[ -z "$service_name" ]] || [[ "$service_name" == "--help" ]] || [[ "$service_name" == "-h" ]]; then
        show_usage
        exit 1
    fi
    
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        print_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    create_service "$service_name"
}

# Run main function with all arguments
main "$@"
