.PHONY: up down re fast help

up:
	docker compose --profile pipeline up --build

fast:
	docker compose --profile pipeline up

down:
	docker compose --profile pipeline down --remove-orphans
	docker network rm routing_net 2>/dev/null || true

re: down up

help:
	@echo "make up    - build and start the full pipeline (use this first)"
	@echo "make fast  - start without rebuild (after first run)"
	@echo "make down  - stop and clean up"
	@echo "make re    - restart from scratch (down + up)"