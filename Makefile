up:
	docker compose --profile pipeline up

down:
	docker compose --profile pipeline down --remove-orphans
	docker network rm routing_net 2>/dev/null || true

re: down up

pipeline:
	docker compose --profile pipeline up --build