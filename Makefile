.PHONY: build up down restart rebuild rebuild-clean logs status health \
        shell prune prune-all deploy supabase-push supabase-functions help

ENV_FILE := .env
CONTAINER := pronghorn-frontend
COMPOSE   := docker compose --env-file $(ENV_FILE)

# ── Default target ─────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help

# ── Build ──────────────────────────────────────────────────────────────────────

## Build the Docker image (uses layer cache)
build:
	$(COMPOSE) build

## Build with no cache — use after changing .env.local or package.json
rebuild-clean:
	$(COMPOSE) build --no-cache

# ── Run ────────────────────────────────────────────────────────────────────────

## Start the container detached
up:
	$(COMPOSE) up -d

## Build and start in one step
deploy: build up

## Stop and remove the container (keeps the image)
down:
	$(COMPOSE) down

## Stop, rebuild (cached), and restart
restart: down build up

## Stop, rebuild from scratch, and restart
rebuild: down rebuild-clean up

# ── Inspect ────────────────────────────────────────────────────────────────────

## Show running container status
status:
	$(COMPOSE) ps

## Check container health (should print "healthy" after ~30s)
health:
	docker inspect $(CONTAINER) --format='{{.State.Health.Status}}'

## Tail live logs
logs:
	$(COMPOSE) logs -f frontend

## Open a shell inside the running container
shell:
	docker exec -it $(CONTAINER) /bin/sh

# ── Cleanup ────────────────────────────────────────────────────────────────────

## Remove the container and its image
prune:
	$(COMPOSE) down --rmi local

## Remove container, image, volumes, and orphaned containers
prune-all:
	$(COMPOSE) down --rmi all --volumes --remove-orphans

# ── Supabase ───────────────────────────────────────────────────────────────────

## Push database migrations to Supabase
supabase-push:
	npx supabase db push

## Deploy all edge functions to Supabase
supabase-functions:
	npx supabase functions deploy

# ── Help ───────────────────────────────────────────────────────────────────────

## Print this help message
help:
	@echo ""
	@echo "Pronghorn — available make targets"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^##/ { desc=$$0; sub(/^## /,"",desc) } \
	      /^[a-zA-Z_-]+:/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, desc; desc="" }' $(MAKEFILE_LIST)
	@echo ""