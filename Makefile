# Traefik Homelab Management Makefile
.PHONY: help start stop restart status logs validate clean update tunnel-start tunnel-stop tunnel-restart tunnel-status tunnel-logs

# Default target
help:
	@echo "🚀 Traefik Homelab Management Commands:"
	@echo ""
	@echo "📊 Service Management:"
	@echo "  make start [service]     - Start service(s) (all, traefik, jellyfin, qbittorrent, radarr, sonarr, prowlarr)"
	@echo "  make stop [service]      - Stop service(s)"
	@echo "  make restart [service]   - Restart service(s) (restarts Traefik when needed)"
	@echo "  make status              - Check all services status"
	@echo "  make logs [service]      - View service logs"
	@echo ""
	@echo "🌐 Tunnel Management:"
	@echo "  make tunnel-start        - Start Cloudflare tunnel"
	@echo "  make tunnel-stop         - Stop Cloudflare tunnel"
	@echo "  make tunnel-restart      - Restart tunnel"
	@echo "  make tunnel-status       - Check tunnel status"
	@echo "  make tunnel-logs         - View tunnel logs"
	@echo ""
	@echo "🔧 Maintenance:"
	@echo "  make validate            - Run health checks"
	@echo "  make clean               - Clean up containers/networks"
	@echo "  make update              - Update all services"
	@echo ""
	@echo "🚀 Service Creation:"
	@echo "  make create-service SERVICE_NAME=myapp  - Create new service from template"
	@echo "  make add-service SERVICE_NAME=myapp     - Integrate service with Traefik"
	@echo "  make show-template                      - View service template"
	@echo ""
	@echo "💡 Examples:"
	@echo "  make start all           - Start all services"
	@echo "  make restart jellyfin    - Restart Jellyfin + Traefik"
	@echo "  make logs traefik        - View Traefik logs"

# Variables
SERVICES := traefik jellyfin qbittorrent radarr sonarr prowlarr testapp
MAIN_COMPOSE := docker-compose.yml
SERVICE_DIR := services

# Service Management
start: start-$(or $(filter-out all,$(filter $(firstword $(MAKECMDGOALS)),$(SERVICES))),all)

start-all: start-traefik
	@echo "🚀 Starting all services..."
	@for service in $(filter-out traefik,$(SERVICES)); do \
		echo "Starting $$service..."; \
		$(MAKE) start-$$service; \
	done
	@echo "✅ All services started!"

start-traefik:
	@echo "🚀 Starting Traefik..."
	@docker compose -f $(MAIN_COMPOSE) up -d traefik
	@echo "✅ Traefik started!"

start-jellyfin:
	@echo "🚀 Starting Jellyfin..."
	@docker compose -f $(SERVICE_DIR)/jellyfin/docker-compose.yml up -d
	@echo "✅ Jellyfin started!"

start-qbittorrent:
	@echo "🚀 Starting qBittorrent..."
	@docker compose -f $(SERVICE_DIR)/qbittorrent/docker-compose.yml up -d
	@echo "✅ qBittorrent started!"

start-radarr:
	@echo "🚀 Starting Radarr..."
	@docker compose -f $(SERVICE_DIR)/radarr/docker-compose.yml up -d
	@echo "✅ Radarr started!"

start-sonarr:
	@echo "🚀 Starting Sonarr..."
	@docker compose -f $(SERVICE_DIR)/sonarr/docker-compose.yml up -d
	@echo "✅ Sonarr started!"

start-prowlarr:
	@echo "🚀 Starting Prowlarr..."
	@docker compose -f $(SERVICE_DIR)/prowlarr/docker-compose.yml up -d
	@echo "✅ Prowlarr started!"

# Stop services
stop: stop-$(or $(filter-out all,$(filter $(firstword $(MAKECMDGOALS)),$(SERVICES))),all)

stop-all:
	@echo "🛑 Stopping all services..."
	@docker compose -f $(MAIN_COMPOSE) down
	@for service in $(filter-out traefik,$(SERVICES)); do \
		echo "Stopping $$service..."; \
		$(MAKE) stop-$$service; \
	done
	@echo "✅ All services stopped!"

stop-traefik:
	@echo "🛑 Stopping Traefik..."
	@docker compose -f $(MAIN_COMPOSE) stop traefik
	@echo "✅ Traefik stopped!"

stop-jellyfin:
	@echo "🛑 Stopping Jellyfin..."
	@docker compose -f $(SERVICE_DIR)/jellyfin/docker-compose.yml down
	@echo "✅ Jellyfin stopped!"

stop-qbittorrent:
	@echo "🛑 Stopping qBittorrent..."
	@docker compose -f $(SERVICE_DIR)/qbittorrent/docker-compose.yml down
	@echo "✅ qBittorrent stopped!"

stop-radarr:
	@echo "🛑 Stopping Radarr..."
	@docker compose -f $(SERVICE_DIR)/radarr/docker-compose.yml down
	@echo "✅ Radarr stopped!"

stop-sonarr:
	@echo "🛑 Stopping Sonarr..."
	@docker compose -f $(SERVICE_DIR)/sonarr/docker-compose.yml down
	@echo "✅ Sonarr stopped!"

stop-prowlarr:
	@echo "🛑 Stopping Prowlarr..."
	@docker compose -f $(SERVICE_DIR)/prowlarr/docker-compose.yml down
	@echo "✅ Prowlarr stopped!"

# Restart services (always restarts Traefik when needed)
restart: restart-$(or $(filter-out all,$(filter $(firstword $(MAKECMDGOALS)),$(SERVICES))),all)

restart-all:
	@echo "🔄 Restarting all services..."
	@$(MAKE) stop-all
	@$(MAKE) start-all
	@echo "✅ All services restarted!"

restart-traefik:
	@echo "🔄 Restarting Traefik..."
	@docker compose -f $(MAIN_COMPOSE) restart traefik
	@echo "✅ Traefik restarted!"

restart-jellyfin:
	@echo "🔄 Restarting Jellyfin + Traefik..."
	@docker compose -f $(SERVICE_DIR)/jellyfin/docker-compose.yml down
	@docker compose -f $(SERVICE_DIR)/jellyfin/docker-compose.yml up -d
	@docker compose -f $(MAIN_COMPOSE) restart traefik
	@echo "✅ Jellyfin + Traefik restarted!"

restart-qbittorrent:
	@echo "🔄 Restarting qBittorrent + Traefik..."
	@docker compose -f $(SERVICE_DIR)/qbittorrent/docker-compose.yml down
	@docker compose -f $(SERVICE_DIR)/qbittorrent/docker-compose.yml up -d
	@docker compose -f $(MAIN_COMPOSE) restart traefik
	@echo "✅ qBittorrent + Traefik restarted!"

restart-radarr:
	@echo "🔄 Restarting Radarr + Traefik..."
	@docker compose -f $(SERVICE_DIR)/radarr/docker-compose.yml down
	@docker compose -f $(SERVICE_DIR)/radarr/docker-compose.yml up -d
	@docker compose -f $(MAIN_COMPOSE) restart traefik
	@echo "✅ Radarr + Traefik restarted!"

restart-sonarr:
	@echo "🔄 Restarting Sonarr + Traefik..."
	@docker compose -f $(SERVICE_DIR)/sonarr/docker-compose.yml down
	@docker compose -f $(SERVICE_DIR)/sonarr/docker-compose.yml up -d
	@docker compose -f $(MAIN_COMPOSE) restart traefik
	@echo "✅ Sonarr + Traefik restarted!"

restart-prowlarr:
	@echo "🔄 Restarting Prowlarr + Traefik..."
	@docker compose -f $(SERVICE_DIR)/prowlarr/docker-compose.yml down
	@docker compose -f $(SERVICE_DIR)/prowlarr/docker-compose.yml up -d
	@docker compose -f $(MAIN_COMPOSE) restart traefik
	@echo "✅ Prowlarr + Traefik restarted!"

# Status and logs
status:
	@echo "📊 Service Status:"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(traefik|jellyfin|qbittorrent|radarr|sonarr|prowlarr)" || echo "No services running"

logs:
	@if [ -n "$(filter $(firstword $(MAKECMDGOALS)),$(SERVICES))" ]; then \
		docker logs -f $(filter $(firstword $(MAKECMDGOALS)),$(SERVICES)); \
	else \
		echo "Usage: make logs [service]"; \
		echo "Available services: $(SERVICES)"; \
	fi

# Tunnel management
tunnel-start:
	@echo "🌐 Starting Cloudflare tunnel..."
	@./scripts/tunnel.sh start

tunnel-stop:
	@echo "🌐 Stopping Cloudflare tunnel..."
	@./scripts/tunnel.sh stop

tunnel-restart:
	@echo "🌐 Restarting Cloudflare tunnel..."
	@./scripts/tunnel.sh restart

tunnel-status:
	@echo "🌐 Cloudflare tunnel status:"
	@./scripts/tunnel.sh status

tunnel-logs:
	@echo "🌐 Cloudflare tunnel logs:"
	@./scripts/tunnel.sh logs

# Maintenance
validate:
	@echo "🔍 Running health checks..."
	@./scripts/validate.sh

clean:
	@echo "🧹 Cleaning up containers and networks..."
	@docker compose -f $(MAIN_COMPOSE) down
	@for service in $(filter-out traefik,$(SERVICES)); do \
		docker compose -f $(SERVICE_DIR)/$$service/docker-compose.yml down; \
	done
	@docker network prune -f
	@docker system prune -f
	@echo "✅ Cleanup complete!"

update:
	@echo "🔄 Updating all services..."
	@for service in $(SERVICES); do \
		if [ "$$service" = "traefik" ]; then \
			docker compose -f $(MAIN_COMPOSE) pull traefik; \
		else \
			docker compose -f $(SERVICE_DIR)/$$service/docker-compose.yml pull; \
		fi; \
	done
	@echo "✅ All services updated! Run 'make restart all' to apply updates."

# Force recreation (useful for label changes)
force-recreate:
	@echo "🔄 Force recreating all services..."
	@docker compose -f $(MAIN_COMPOSE) up -d --force-recreate traefik
	@for service in $(filter-out traefik,$(SERVICES)); do \
		echo "Force recreating $$service..."; \
		docker compose -f $(SERVICE_DIR)/$$service/docker-compose.yml up -d --force-recreate; \
	done
	@echo "✅ All services force recreated!"

# Quick access to specific service
jellyfin: start-jellyfin
qbit: start-qbittorrent
radarr: start-radarr
sonarr: start-sonarr
prowlarr: start-prowlarr

# Service creation and management
create-service:
	@if [ -z "$(SERVICE_NAME)" ]; then \
		echo "Usage: make create-service SERVICE_NAME=myapp"; \
		echo ""; \
		echo "This creates a new service directory with a template docker-compose.yml file."; \
		echo ""; \
		echo "Example:"; \
		echo "  make create-service SERVICE_NAME=myapp"; \
		echo ""; \
		echo "After editing the file, run:"; \
		echo "  make add-service SERVICE_NAME=myapp"; \
		exit 1; \
	fi
	@echo "🚀 Creating service: $(SERVICE_NAME)"
	@./scripts/create-service.sh $(SERVICE_NAME)

add-service:
	@if [ -z "$(SERVICE_NAME)" ]; then \
		echo "Usage: make add-service SERVICE_NAME=myapp"; \
		echo ""; \
		echo "This automatically integrates a new service with Traefik."; \
		echo ""; \
		echo "Example:"; \
		echo "  make add-service SERVICE_NAME=myapp"; \
		echo ""; \
		echo "Prerequisites:"; \
		echo "  1. Service directory must exist in services/$(SERVICE_NAME)"; \
		echo "  2. docker-compose.yml must be configured"; \
		exit 1; \
	fi
	@echo "⚡ Adding service: $(SERVICE_NAME)"
	@./scripts/add-service.sh $(SERVICE_NAME)

# Service template management
show-template:
	@echo "📋 Service template location: scripts/service-template.yml"
	@echo ""
	@echo "Template contents:"
	@cat scripts/service-template.yml
