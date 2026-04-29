# docker orchestration

This document describes the services and what they are in charge of,
which volumes are persistent, how to use the two profiles and to what
end, and the most basic security measure taken.

This is a development project, and the yml reflects this. Once the
project feels satisfying to me, I'll step up to production.

## docker structure

```
docker compose
├── core services
│   ├── db           (PostGIS/pgRouting database)
│   └── api          (Flask API)
├── pipeline profile
│   ├── loader       (data import)
│   └── builder      (graph build)
└── devtools profile
    └── builder_dev  (manual export / debug service for Linux users)
```

## services roles

Intent: run the whole pipeline in one command:

```bash
make up
```

(`make up` rebuilds the images first; `make fast` runs without rebuild.
See the [Makefile](../Makefile) or run `make help`.)

The core responsibilities have been separated into different services
(loader, builder) so the yml can orchestrate:

- the core services setup
- then the loader imports data
- then the builder runs the SQL logic

Every critical service checks if the one it requires is either up and
healthy, or has run and exited with no error signal.

### core services

Those two services are up with `make up`, persistent, and always running.

1. **db**

   This service contains the core engine in SQL. It is always up, and
   the database is consistent unless you run `docker compose down -v`.

2. **api**

   This service contains the Flask routes that interrogate the database
   and serve an itinerary to a (future) frontend.

### profiles

The profiles help run the pipeline and solve an export problem
encountered as a new Linux user.

1. **"pipeline" profile**

   It contains 2 services:

   a. **loader**

   Service in charge of importing data into the database.
   Intent: make sure the data loading is done **after** the database
   is up and healthy.

   b. **builder** ("injection of SQL logic")

   Intent: make sure this service runs all necessary `MASTER.sql`
   files to set up steps 4–7 of the pipeline (see
   [pipeline.md](./pipeline.md)) **after** the loader has run and
   exited with no errors.

2. **"devtools" profile**

   You do not need this profile if you are a Windows or Mac user.

   This profile was created for Linux users. Its goal is to **export
   files from the database with the UID/GID mapped in the `.env`
   file**.

   You can code, modify, and run files in the db service, but it uses
   a Postgres UID/GID. It would not work if you wanted to force your
   own UID/GID on it to export files.

   The Makefile (`make up`, `make fast`, etc.) covers the day-to-day
   development cycle. Devtools commands are kept as direct
   `docker compose` invocations below because they target one-off,
   ad-hoc operations (export this table, run that SQL file) where
   wrapping each variation in a Makefile target would add more noise
   than clarity.

   **Export command examples:**

   ```bash
   docker compose --profile devtools run --rm builder_dev psql -f /path/to/file_to_export.sql
   ```

   (`/DEBUG/` will contain files ready to export in geojson.)

   ```bash
   docker compose --profile devtools run --rm builder_dev psql -c "\COPY table_name TO '/exports/results.csv' CSV"
   ```

## Security is in the .env

The `.env` file (download link in the [readme.md](../readme.md)) stores
the services' ids and passwords as variables so they don't have to be
hardcoded in the yml. It is never committed to git.

(Security is the next phase of the project so I took the most basic
security step possible — I'll get better.)

---

## Known issues in development

### Orphan networks after an interrupted run

When a `docker compose up` is interrupted abruptly (Ctrl+C during a
build, a container crash, or a terminal closed before `make down`
completes), the project's Docker network can be left in an inconsistent
state. A subsequent `make fast` then fails with a network conflict
error, even though the previous services appear to be stopped.

#### Why this happens

The `make down` target explicitly removes the project's network:

```makefile
down:
	docker compose --profile pipeline down --remove-orphans
	docker network rm routing_net 2>/dev/null || true
```

When `make down` doesn't execute (because the previous run was
interrupted before reaching it), the network `routing_net` remains in
place with allocated IPs that no longer match any running container.
The next `make fast` cannot reconcile the state, because it tries to
attach to an existing-but-stale network.

#### Current workaround

In practice, `make up` (which rebuilds the images, taking about a
minute) succeeds where `make fast` fails. The mechanism is empirical:
the rebuild itself doesn't act on the network, but the time it takes
gives the Docker daemon enough room to clean up stale references in
the background. This is observed, not designed.

#### Reliable cleanup, in order of severity

If `make up` is not enough, the following commands escalate from
targeted cleanup to last-resort cleanup. Try them in order — most of
the time, level 1 or level 2 is sufficient.

```bash
# Level 1 — standard cleanup
make down

# Level 2 — explicit network removal (when make down was incomplete)
docker network rm routing_net

# Level 3 — last resort (read the warning below first)
docker network prune -f
```

> ⚠️ **`docker network prune -f` is destructive.** It removes every
> custom Docker network on the machine that has no container currently
> attached to it — including networks belonging to **other** Docker
> projects whose services happen to be stopped. Default Docker networks
> (`bridge`, `host`, `none`) are protected, but custom networks created
> by other `docker-compose.yaml` files are not.
>
> If other Docker projects rely on specific network configurations,
> their next `up` command will recreate the networks fresh — usually
> harmless, but worth knowing before running `prune -f`. If you have
> any doubt, prefer Level 2 (targeted removal of `routing_net` only).

#### Why this isn't an issue in production

Production deployments run continuously. The crash-restart cycle that
triggers orphan networks is a development artefact: in production,
services either run or they're explicitly redeployed, with no rapid
crash-and-restart pattern.

A cleaner long-term fix (a dedicated `make reset` command that
guarantees full network cleanup, or declaring the network as external
to docker-compose) is tracked but not yet implemented.
