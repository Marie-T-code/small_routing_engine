.DEFAULT_GOAL := help
.PHONY: help build pipeline up down psql export-sql test-api

help:
	@echo "make build      - rebuild Docker images"
	@echo "make pipeline   - import data and build the graph (loader + builder)"
	@echo "make up         - start db + api"
	@echo "make down       - stop and remove all containers (all profiles)"
	@echo "make psql       - open a psql session in the db container"
	@echo "make export-sql - FILE=path/to/file.sql - run a SQL file as your user (Linux exports; path relative to SQL/)"
	@echo "make test-api   - run the curl end-to-end test suite"
	@echo ""
	@echo "First run:  make build pipeline up"

build:
	docker compose --profile "*" build

pipeline:
	docker compose --profile pipeline run --rm loader
	docker compose --profile pipeline run --rm --no-deps builder

up:
	docker compose up

down:
	docker compose --profile "*" down

psql:
	docker exec -it $$(docker compose ps -q db) psql

export-sql:
	@test -n "$(FILE)" || (echo "Usage: make export-sql FILE=path/to/file.sql (path relative to SQL/)" && exit 1)
	UID=$$(id -u) GID=$$(id -g) docker compose --profile devtools run --rm builder_dev psql -f /SQL/$(FILE)

test-api:
	bash tests/curl/test_api.sh
