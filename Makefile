.PHONY: up fast down reset re psql run-sql test-api help

up:
	docker compose --profile pipeline up --build

fast:
	docker compose up

down:
	docker compose down

reset:
	docker compose --profile pipeline down --remove-orphans
	docker network rm routing_net 2>/dev/null || true

re:
	make reset
	make fast

psql:
	docker exec -it $$(docker compose ps -q db) psql

run-sql:
	@test -n "$(FILE)" || (echo "Usage: make run-sql FILE=path/to/file.sql" && exit 1)
	docker compose --profile devtools run --rm builder_dev psql -f /SQL/$(FILE)

test-api:
	bash tests/curl/test_api.sh

help:
	@echo "make up         - build and start the full pipeline (use this first)"
	@echo "make fast       - start without rebuild (after first run)"
	@echo "make down       - stop"
	@echo "make reset      - stop and clean up after crashes"
	@echo "make re         - quick restart (reset + fast)"
	@echo "make psql       - open a psql session in the db container"
	@echo "make run-sql FILE=path/to/file.sql - run a psql script via devtools - handy for exports on Linux"
	@echo "make test-api   - run the curl end-to-end test suite"