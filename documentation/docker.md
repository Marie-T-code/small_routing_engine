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

   The Makefile (`make up`, `make fast`, `make reset`, etc.) covers the
   day-to-day development cycle. Devtools commands are kept as direct
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

When a `docker compose up` is interrupted abruptly (Ctrl+C twice during
startup, a container crash, or a terminal closed before `make down`
completes), the project's containers can be left holding a reference to
a Docker network that no longer exists in the daemon's state. The next
`make up` (or `make fast`) then fails with:

```
failed to set up container networking: network <id> not found
```

#### Why this happens

A `docker compose down` does two things atomically: it removes the
project's containers, then removes the network they were attached to.
If the down sequence is killed midway, the network can be deleted from
the daemon while the containers' configuration still points to its old
ID. On the next `up`, Docker creates a fresh `routing_net` with a
**new** ID, but the existing containers try to attach to the **old**
ID and fail.

It's worth noting that the issue isn't a "zombie network" floating
around — it's the inverse: the network is gone, and the containers are
still looking for it.

#### Solution: `make reset`

```bash
make reset
make up
```

`make reset` runs:

```makefile
reset:
	docker compose --profile pipeline down --remove-orphans
	docker network rm routing_net 2>/dev/null || true
```

Two things matter here:

- **`--remove-orphans`** is the key flag. A standard `docker compose
  down` only removes containers that match the *current* compose
  definition. Containers in inconsistent states (referencing a dead
  network ID) may fall outside that definition and be skipped.
  `--remove-orphans` forces the removal of every container carrying
  the project's compose label, regardless of state.

- **`docker network rm routing_net`** is a safety net. In rare cases
  a stale network can survive the `down` step. The `2>/dev/null
  || true` makes the command silent and non-failing when the network
  is already gone, so `make reset` is always safe to run.

This is why `make down` and `make reset` are deliberately separate
commands. `make down` is the standard teardown for a normal session
and stays minimal; `make reset` is explicitly a recovery command, and
its name reflects that intent.

#### If `make reset` is not enough

In rare cases (e.g. another Docker process holding a lock on the
network), the targeted cleanup may not succeed. The following
commands escalate from explicit removal to last-resort cleanup:

```bash
# Explicit network removal (when make reset reported nothing removed)
docker network rm routing_net

# Last resort — read the warning below first
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
> any doubt, prefer the targeted `docker network rm routing_net`.

#### Why this isn't an issue in production

Production deployments run continuously. The crash-restart cycle that
triggers orphan network references is a development artefact: in
production, services either run or they're explicitly redeployed,
with no rapid crash-and-restart pattern.

A cleaner long-term fix (declaring the network as `external` to
docker-compose, so its lifecycle is decoupled from compose's `up`/`down`)
is tracked but not yet implemented — `make reset` covers the use case
adequately for the current development scope.
