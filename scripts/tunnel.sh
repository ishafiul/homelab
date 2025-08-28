#!/bin/bash

# Cloudflare Tunnel Management Script
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

case "$1" in
    start)
        print_status "Starting Cloudflare tunnel..."
        if pgrep -f "cloudflared tunnel" > /dev/null; then
            print_warning "Tunnel is already running"
            exit 0
        fi
        nohup cloudflared tunnel --config ./tunnel-config.yml run > cloudflared.log 2>&1 &
        sleep 3
        if pgrep -f "cloudflared tunnel" > /dev/null; then
            print_status "Tunnel started successfully"
            echo "Log: tail -f cloudflared.log"
        else
            print_error "Failed to start tunnel"
            exit 1
        fi
        ;;
    stop)
        print_status "Stopping Cloudflare tunnel..."
        pkill -f "cloudflared tunnel" || print_warning "No tunnel process found"
        print_status "Tunnel stopped"
        ;;
    status)
        if pgrep -f "cloudflared tunnel" > /dev/null; then
            print_status "Tunnel is running"
            echo "Process: $(pgrep -f 'cloudflared tunnel')"
        else
            print_warning "Tunnel is not running"
        fi
        ;;
    logs)
        if [ -f cloudflared.log ]; then
            tail -f cloudflared.log
        else
            print_error "Log file not found"
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs|restart}"
        echo
        echo "Commands:"
        echo "  start   - Start the Cloudflare tunnel"
        echo "  stop    - Stop the Cloudflare tunnel"
        echo "  status  - Check tunnel status"
        echo "  logs    - View tunnel logs"
        echo "  restart - Restart the tunnel"
        exit 1
        ;;
esac
