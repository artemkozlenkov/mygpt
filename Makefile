# myGPT Management Makefile
# Usage: make <target>
#   make          — Show this help
#   make start    — Start all containers
#   make stop     — Stop all containers

COMPOSE_FILE := compose.yml

# ─── Detect OS ────────────────────────────────────────────────────────────────
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
  OPEN := xdg-open
else ifeq ($(UNAME_S),Darwin)
  OPEN := open
endif

# ─── Colors ───────────────────────────────────────────────────────────────────
BOLD := \033[1m
DIM  := \033[2m
GREEN := \033[32m
YELLOW := \033[33m
CYAN := \033[36m
RED := \033[31m
NC := \033[0m

# ─── Default target ───────────────────────────────────────────────────────────
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo ""
	@echo "$(BOLD)myGPT Management$(NC)"
	@echo "$(DIM)──────────────────────────────────────────────────────$(NC)"
	@echo ""
	@echo "$(CYAN)Usage:$(NC)  make $(YELLOW}<target>$(NC)"
	@echo ""
	@echo "$(BOLD)Core commands$(NC)"
	@echo "  $(GREEN)start$(NC)     Start all containers in detached mode"
	@echo "  $(GREEN)stop$(NC)      Stop all containers"
	@echo "  $(GREEN)restart$(NC)   Restart all containers"
	@echo "  $(GREEN)status$(NC)    Show container status (alias: $(GREEN)ps$(NC))"
	@echo ""
	@echo "$(BOLD)Logs & monitoring$(NC)"
	@echo "  $(GREEN)logs$(NC)      Tail logs from all services"
	@echo "  $(GREEN)logs/svc$(NC)  Tail logs from one service  (e.g. $(DIM)make logs/svc svc=litellm$(NC))"
	@echo ""
	@echo "$(BOLD)Setup & maintenance$(NC)"
	@echo "  $(GREEN)setup$(NC)     Create .env files from .example templates"
	@echo "  $(GREEN)pull$(NC)      Pull latest Docker images"
	@echo "  $(GREEN)config$(NC)    Validate compose.yml syntax"
	@echo "  $(GREEN)clean$(NC)     Stop containers and remove volumes"
	@echo "  $(GREEN)gitleaks$(NC)  Run Gitleaks security scan"
	@echo ""
	@echo "$(BOLD)Convenience$(NC)"
	@echo "  $(GREEN)open-ui$(NC)   Open OpenWebUI (https://chat.softawebit.com — tailnet)"
	@echo "  $(GREEN)open-proxy$(NC) LiteLLM is internal-only; shows access commands"
	@echo "  $(GREEN)caddy-reload$(NC) Reload Caddy config after editing Caddyfile"
	@echo "  $(GREEN)shell/svc$(NC) Open a shell in a running container (e.g. $(DIM)make shell/svc svc=db$(NC))"
	@echo ""

# ─── Core ─────────────────────────────────────────────────────────────────────

.PHONY: start
start: ensure-env ## Start all containers in detached mode
	@echo "$(BOLD)Starting containers...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d
	@echo ""
	@echo "$(GREEN)✓ Containers started.$(NC)"
	@echo "  OpenWebUI:  $(CYAN)https://chat.softawebit.com$(NC) (tailnet only)"
	@echo "  LiteLLM:    $(DIM)internal only (make logs/svc svc=litellm)$(NC)"
	@echo "  SearxNG:    $(DIM)internal only (web search via OpenWebUI)$(NC)"

.PHONY: stop
stop: ## Stop all containers
	@echo "$(BOLD)Stopping containers...$(NC)"
	docker compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)✓ Containers stopped.$(NC)"

.PHONY: restart
restart: stop start ## Restart all containers

.PHONY: status ps
status ps: ## Show container status
	@echo "$(BOLD)Container status:$(NC)"
	docker compose -f $(COMPOSE_FILE) ps

# ─── Logs ─────────────────────────────────────────────────────────────────────

.PHONY: logs
logs: ## Tail logs from all services
	docker compose -f $(COMPOSE_FILE) logs --tail=50 -f

.PHONY: logs/svc
logs/svc: ## Tail logs from one service  (make logs/svc svc=<name>)
	@if [ -z "$(svc)" ]; then \
		echo "$(RED)Usage: make logs/svc svc=<service-name>$(NC)"; \
		echo "Available: litellm openwebui db redis searxng"; \
		exit 1; \
	fi
	docker compose -f $(COMPOSE_FILE) logs --tail=100 -f "$(svc)"

# ─── Setup & Maintenance ──────────────────────────────────────────────────────

.PHONY: ensure-env
ensure-env:
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)…$(NC) .env not found — creating from .env.example"; \
		$(MAKE) setup; \
	fi

.PHONY: setup
setup: ## Create .env file from .env.example (will NOT overwrite existing)
	@echo "$(BOLD)Setting up environment file...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "  $(GREEN)✓$(NC) Created .env from .env.example"; \
	else \
		echo "  $(YELLOW)…$(NC) .env already exists — skipping"; \
	fi
	@echo "$(GREEN)✓ Setup complete. Edit .env with your API keys before starting.$(NC)"

.PHONY: pull
pull: ## Pull latest Docker images defined in compose.yml
	@echo "$(BOLD)Pulling images...$(NC)"
	docker compose -f $(COMPOSE_FILE) pull
	@echo "$(GREEN)✓ Images up to date.$(NC)"

.PHONY: config
config: ensure-env ## Validate compose.yml syntax
	@echo "$(BOLD)Validating compose.yml...$(NC)"
	docker compose -f $(COMPOSE_FILE) config --quiet
	@echo "$(GREEN)✓ Syntax OK.$(NC)"

.PHONY: clean
clean: ## Stop containers and remove volumes (WARNING: destroys database data)
	@echo "$(YELLOW)⚠  This will remove all container data (volumes).$(NC)"
	@read -p "Are you sure? [y/N] " reply; \
	if [ "$$reply" = "y" ] || [ "$$reply" = "Y" ]; then \
		echo "$(BOLD)Stopping and cleaning up...$(NC)"; \
		docker compose -f $(COMPOSE_FILE) down -v; \
		echo "$(GREEN)✓ Cleaned up.$(NC)"; \
	else \
		echo "$(YELLOW)Aborted.$(NC)"; \
	fi

GITLEAKS_VERSION ?= v8.30.1

.PHONY: gitleaks
gitleaks: ## Run Gitleaks security scan (local binary if present, else pinned Docker image)
	@echo "$(BOLD)Running Gitleaks security scan...$(NC)"
	@if command -v gitleaks >/dev/null 2>&1; then \
		gitleaks detect --source . --no-banner; \
	else \
		docker run --rm -v "$(PWD):/src" -w /src gitleaks/gitleaks:$(GITLEAKS_VERSION) detect --source .; \
	fi
	@echo "$(GREEN)✓ Scan complete.$(NC)"

# ─── Convenience ──────────────────────────────────────────────────────────────

.PHONY: open-ui
open-ui: ## Open OpenWebUI in browser (HTTPS, tailnet only)
	@echo "$(BOLD)Opening OpenWebUI...$(NC)"
	$(OPEN) https://chat.softawebit.com

.PHONY: open-proxy
open-proxy: ## Show how to reach the internal-only LiteLLM proxy
	@echo "$(BOLD)LiteLLM is internal-only (not exposed over HTTPS).$(NC)"
	@echo "  Health:    docker compose exec litellm python3 -c \"import urllib.request as u; print(u.urlopen('http://localhost:4000/health/liveliness').read().decode())\""
	@echo "  Shell:     make shell/svc svc=litellm"
	@echo "  Logs:      make logs/svc svc=litellm"

.PHONY: shell/svc
shell/svc: ## Open a shell in a running container  (make shell/svc svc=<name>)
	@if [ -z "$(svc)" ]; then \
		echo "$(RED)Usage: make shell/svc svc=<service-name>$(NC)"; \
		echo "Available: litellm openwebui db redis searxng caddy"; \
		exit 1; \
	fi
	docker compose -f $(COMPOSE_FILE) exec "$(svc)" sh

.PHONY: caddy-reload
caddy-reload: ## Reload Caddy config after editing Caddyfile (no downtime)
	@echo "$(BOLD)Reloading Caddy...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec caddy caddy reload --config /etc/caddy/Caddyfile
	@echo "$(GREEN)✓ Caddy reloaded.$(NC)"
