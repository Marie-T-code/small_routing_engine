# Project architecture

This document describes how the project is structured as a whole: the
top-level layout, the principle that separates the SQL engine from the
Python application, and then each layer in turn — the SQL engine and its
build pipeline, the Python API, and the test suites.

For the spatial data structures themselves (tables, views, columns),
see [`data_model.md`](./data_model.md).
For the runtime function reference, see
[`engine_functions.md`](./engine_functions.md).

---

## Overview

### Top-level layout

Only the structural directories are shown here — generated, vendored, and
gitignored folders (caches, `venv`, data dumps, personal notes) are
omitted.

```text
small_routing_engine/
├── SQL/              # The engine: preprocessing, graph build, routing functions (PL/pgSQL)
├── docker/           # Loader (ogr2ogr import) + builder (runs the SQL masters)
├── DB/               # PostGIS image build context + init scripts
├── app/              # Flask API (layered OOP) — routes + pois services
├── tests/            # E2E (curl) + integration (pytest)
└── documentation/    # Detailed docs (this file lives here)
```

Each structural directory is detailed in its own section below.

### The guiding principle: SQL is the engine, Python orchestrates

The routing engine lives entirely in SQL/PL-pgSQL: graph construction,
snapping, the Dijkstra call, metrics, and GeoJSON export are all database
functions. Python does not re-implement any routing logic — it opens a
connection, calls the SQL entry points, maps structured database errors to
HTTP responses, and serves the result. This keeps a single source of truth
(the database) and makes each layer independently testable.

The rest of this document follows that split: the SQL engine and its build
pipeline first, then the Python application that exposes it, then the tests.

### A numbered, sequential SQL pipeline

The `SQL/` directory is organised as a **numbered, sequential pipeline**.
Each top-level directory corresponds to one stage of the build, and the
numeric prefixes encode the execution order. Three master scripts
orchestrate the pipeline; nothing in the SQL layer is meant to be run
ad hoc.

The build sequence is **safe to re-run** at the master level — functions
use either `CREATE OR REPLACE` (when the signature is stable) or
`DROP IF EXISTS` followed by `CREATE` (when the function signature is
still evolving), and the graph creation step explicitly drops the
vertices table before invoking `pgr_createTopology` to ensure consistent
vertex generation. Re-running on an already-built database is safe; full
idempotence at the lowest level is tracked for a future revision (see
*Why the vertices table is dropped before topology creation* below).

---

## The SQL engine

Everything below covers the SQL layer in depth: how `SQL/` is organised, the
master scripts that orchestrate the build, the runtime function dependency
chain, and the two subtleties worth documenting (the vertices-table drop and
the build-time-only guardrails). This is the heart of the project — per the
guiding principle above, all routing logic lives here.

### The `SQL/` directory layout

#### Top-level of `SQL/`

```text
SQL/
├── 01_config/        # Routing constants (SRID, tolerance, defaults)
├── 03_injection/     # Data import scripts called by the loader service
├── 04_graph/         # Preprocessing, graph creation, views, guardrails
├── 05_algorithms/    # Routing functions (Dijkstra family)
├── 06_MASTERS/       # Pipeline orchestration (entry points)
└── XX_tests/         # Validation tests (in progress)
```

> **Note on the missing `02_`.** Directory `02_views/` was originally
> planned at this level but moved to `04_graph/03_views/` when the build
> sequence was reorganised — views are now built **inside** the graph
> stage, not in a separate stage. The numbering gap is preserved as-is
> to keep existing import paths stable; full renumbering is planned for
> a future major schema revision.

#### Zoom — `04_graph/`

The graph construction stage is the heaviest, so it has its own internal
structure:

```text
04_graph/
├── 01_pre_processing/
│   ├── 01_clean_table_structure.sql       # Drop ogr2ogr artefacts
│   ├── 02_add_length_m.sql                # Compute edge length in meters
│   ├── 03_costs_config.sql                # Set cost / reverse_cost
│   └── 04_edges_cleaning.sql              # Remove invalid / degenerate edges
│
├── 02_graph_creation/
│   ├── 01_PGRouting_createTopology_graph_creation.sql  # pgr_createTopology
│   ├── 02_analyzeGraph.sql                # Topology checks
│   ├── 03_check_indexes.sql               # Verify required indexes exist
│   └── 04_edges_check.sql                 # Length sanity checks
│
├── 03_views/
│   ├── routing_edges.sql                  # Stable contract for algorithms
│   └── routing_vertices.sql               # Stable contract for algorithms
│
├── 04_guardrails/
│   ├── assert_graph_preconditions_on.sql  # Generic precondition function
│   ├── assert_graph_preconditions.sql     # Wrapper, uses default args
│   ├── assert_graph_ready_on.sql          # Generic post-build function
│   └── assert_graph_ready.sql             # Wrapper, uses default args
│
└── 05_coverage/
    └── compute_graph_bbox.sql             # Graph coverage area (convex hull + buffer)
```

**Why this internal split.** Each subdirectory corresponds to **one
phase** of the graph build:

- `01_pre_processing/` runs on the raw imported table before pgRouting
  touches it.
- `02_graph_creation/` calls `pgr_createTopology` and validates the
  result.
- `03_views/` exposes the canonical interface used by algorithms.
- `04_guardrails/` defines the validation functions used at build time.
- `05_coverage/` computes the graph coverage area (the convex hull of the
  nodes, buffered) used to reject out-of-area requests.

This phasing means a developer reading the directory understands the
build sequence without having to read the master script.

#### Zoom — `05_algorithms/`

```text
05_algorithms/
├── 00_pre_processing/                    # Shared by all algorithm families
│   ├── is_within_coverage.sql            # Reject input points outside the graph area
│   ├── compute_routing_bbox.sql          # Bounding box around the two endpoints
│   └── snap_to_nearest_node.sql          # API coords → graph vertex
│
└── 01_dijkstra/
    ├── 01_core/
    │   ├── dijkstra_only.sql              # Raw pgr_dijkstra wrapper
    │   └── dijkstra_snap.sql              # Snap + dijkstra
    │
    ├── 02_post_processing/
    │   └── route_metrics.sql              # Distance + time + LineString
    │
    └── 04_export_modes/
        └── export_route_api.sql           # GeoJSON output
```

> **Note on the missing `03_`.** The numbering skips `03_` inside
> `01_dijkstra/`. It once held the `assert_graph_ready` guardrail, which was
> called at runtime on every request; it moved to `04_graph/04_guardrails/`
> when the guardrail strategy shifted from runtime to build-time (see *Why
> guardrails run at build time only* below). As with the top-level `02_`,
> the gap is kept rather than renumbered to avoid churning import paths.

**Why pre-processing sits outside `01_dijkstra/`.** `00_pre_processing/` is
at the `05_algorithms/` level, not inside `01_dijkstra/`, because its steps
— coverage check, bounding box, snapping — are **shared by every routing
algorithm**, present and future. Only the algorithm-specific stages (core,
post-processing, export) live inside a family directory.

**Why `01_dijkstra/` is a nested family.** The directory leaves room for
future algorithm families: `02_a_star/`, `03_isochrones/`, etc. Each family
will hold its own core / post-processing / export stages while reusing the
shared `00_pre_processing/` above, keeping the architecture predictable as
the project grows.

The numbered subdirectories reflect the **runtime flow** of a single route
request: shared pre-processing (coverage → bbox → snap) → core algorithm →
metrics → export.

(`01_dijkstra/` also contains an `xx_debug/` directory — non-production
debug and export helpers, omitted here.)

---

### Build-time orchestration (the masters)

Three master scripts under `06_MASTERS/` define the entry points to the
build pipeline. Masters **only orchestrate** — they contain no business
SQL of their own.

#### `90_MASTER_ALL.sql` — top-level entry

The script run by the builder service in production. It chains the three
phase masters in order.

```sql
\i /SQL/06_MASTERS/00_MASTER_CONFIG.sql
\i /SQL/06_MASTERS/10_MASTER_GRAPH.sql
\i /SQL/06_MASTERS/20_MASTER_ROUTING_FUNCTIONS.sql
```

The numbering (`00`, `10`, `20`) leaves room for inserting a future
master (e.g. `15_MASTER_<FUTURE>.sql`) without renumbering. (POI search is
not an SQL master — it is Python logic layered on the route engine, see
*The Python application*.)

#### `00_MASTER_CONFIG.sql` — runs first

Loads the configuration functions (SRID, topology tolerance, default
speed) before anything else can use them.

```sql
\i /SQL/01_config/routing_constants.sql
```

This master is intentionally minimal: every downstream function depends
on these constants, so they must exist before anything else runs.

#### `10_MASTER_GRAPH.sql` — preprocessing → graph → views → guardrails

The largest master. It executes the full graph build sequence:

```text
PREPROCESSING
  ├─ Clean table structure (drop ogr2ogr artefacts)
  ├─ Compute length_m for each edge
  ├─ Configure cost and reverse_cost
  └─ Remove invalid / degenerate edges (NULL or < 1m)

GRAPH CREATION
  ├─ Define assert_graph_preconditions_on() and its wrapper
  ├─ Drop the vertices table (routes_v1_vertices_pgr)
  │  (guarantees no stale vertices table survives a rebuild —
  │   see the vertices-drop section below)
  ├─ Run pgr_createTopology (creates source / target / vertices table)
  ├─ Verify topology with pgRouting analysis
  ├─ Verify required indexes exist
  └─ Sanity checks on edge lengths

VIEWS
  ├─ Create routing_edges
  └─ Create routing_vertices

POST-BUILD GUARDRAIL
  ├─ Define assert_graph_ready_on() and its wrapper
  └─ Execute SELECT assert_graph_ready()
```

The final `SELECT assert_graph_ready()` is the **single point of
verification** that the graph is in a usable state. If anything is
wrong (missing topology, broken indexes, empty vertices table), this
call fails with a structured error tag (see
[`error_codes_sre.md`](./error_codes_sre.md)) and the build aborts
before any routing function is created.

#### `20_MASTER_ROUTING_FUNCTIONS.sql` — defines the runtime functions

Loads the functions that the API will eventually call:

```text
PREPROCESSING
  └─ snap_to_nearest_node       (API coords → graph vertex)

CORE
  ├─ dijkstra_only              (wraps pgr_dijkstra)
  └─ dijkstra_snap              (snap two endpoints + run dijkstra_only)

POSTPROCESSING
  └─ route_metrics              (distance + time + LineString)

EXPORT
  └─ export_route_api  (single GeoJSON Feature, EPSG:4326)
```


This master is the **last** to run. By the time it executes, the graph
is fully built and validated, so the routing functions can be defined
without checking graph state at every call.

---

### Function dependency chain (route computation)

This is the call flow for a route request (`/api/route`). POI search reuses
the route this chain produces and adds its own Python layer on top — it is
not part of this chain (see *The Python application*).

Before the chain runs, the repository performs an input guard: it calls
`is_within_coverage` on **each** endpoint. A point outside the graph area
raises `COVERAGE:OUT_OF_BOUNDS` (HTTP 422) and the chain never starts. This
guard lives at the repository level, not nested inside the routing functions,
because it validates *user input*, not graph internals.

```text
                  ┌──────────────────────────────────┐
                  │   API: GET /api/route             │
                  │   (Flask Blueprint → Repository)  │
                  └─────────────┬────────────────────┘
                                │
                                ▼
            ┌───────────────────────────────────────┐
            │   is_within_coverage(...)  × 2        │
            │   guard: both endpoints in graph area │
            │   → 422 if outside, else continue     │
            └─────────────┬─────────────────────────┘
                          │
                          ▼
            ┌───────────────────────────────────────┐
            │   export_route_api(...)               │
            │   GeoJSON Feature in API SRID (4326)  │
            └─────────────┬─────────────────────────┘
                          │
                          ▼
            ┌───────────────────────────────────────┐
            │   route_metrics(...)                  │
            │   distance + time + LineString        │
            └─────────────┬─────────────────────────┘
                          │
                          ▼
            ┌───────────────────────────────────────┐
            │   dijkstra_snap(...)                  │
            │   snap two endpoints + run core algo  │
            └─────────────┬─────────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
   ┌────────────────────┐   ┌──────────────────────┐
   │ snap_to_nearest_   │   │ dijkstra_only(...)   │
   │ node(...)          │   │ wraps pgr_dijkstra   │
   │ EPSG:4326 → vertex │   │ on routing_edges     │
   └────────────────────┘   └──────────────────────┘
```

Each level has a **single responsibility**:

- **Coverage guard** runs at the repository level, before any routing —
  validates user input, never touches the graph algorithm.
- **Export** chooses the output format and SRID — never touches routing.
- **Metrics** computes user-facing values from the raw path — never
  touches snapping.
- **Snap+core** orchestrates the lat/lon → vertex translation and the
  actual algorithm.
- **Snap** and **dijkstra_only** are leaf functions: each does one thing.

The chain is **strictly downward**: no function calls anything from a
higher level. This keeps debugging linear (a failure at one level is
isolated to that level) and makes it possible to test each function
independently in psql, without needing the full API stack.

---

### Why the vertices table is dropped before topology creation

`pgr_createTopology()` has an idempotence pitfall with two independent
heads: by default it skips edges whose `source`/`target` are already
populated, and it does not clean the vertices table between runs. Combined,
a rebuild can leave the graph silently inconsistent — the function reports
success while the vertices table no longer matches the edges. The general
mechanics are documented in [`graph_build.md`](./graph_build.md)
(*Idempotence pitfall*); what follows is how **this build** closes both heads.

**How this build closes both heads.** The two heads need two answers:

- **Head one is closed by the loader.** The loader service re-imports
  `routes_v1` fresh on every build (via `ogr2ogr`), so `source`/`target`
  always arrive NULL — the default `rows_where` then processes every edge.
  No manual reset of `source`/`target` is needed in the public pipeline.
- **Head two is closed by an explicit DROP.** Before calling
  `pgr_createTopology`, the graph creation script drops the vertices table:

  ```sql
  DROP TABLE IF EXISTS public.routes_v1_vertices_pgr CASCADE;
  ```

  This guarantees the vertices table is rebuilt from the current edges,
  so it cannot be left missing — regardless of what state `source`/`target`
  happen to be in.

The loader handles the edges side; the DROP handles the vertices side.
Both are required because they address different halves of the same trap.

> **Historical note.** This bug surfaced early in the refactor, *before*
> the loader service existed. Back then the edges table persisted untouched
> across rebuilds: `source`/`target` kept their values (head one) while a
> vertices table that had vanished was never regenerated (head two), which
> produced an empty export despite `pgr_analyzeGraph` reporting success.
> That debugging session is where the idempotency requirement was first
> understood. The loader later removed the need to reset `source`/`target`
> by hand; the DROP remains the guarantee on the vertices side.

**Why an explicit DROP rather than `clean := TRUE`.** Passing
`clean := TRUE` to `pgr_createTopology` would achieve the same vertex-table
reset in a single flag. The explicit `DROP` is preferred here for two
reasons: it states plainly what happens (no need to know the flag's
semantics to read the script), and it does not depend on
`pgr_createTopology` itself, which is deprecated as of pgRouting 3.8 — the
`DROP` is plain SQL that outlives the function. The cost is that the
topology is fully recomputed on every build even when nothing changed;
acceptable for a prototype, refinable later.

This is documented here because it is the kind of subtlety invisible from
the master script alone, and that would otherwise resurface as a debugging
session for any future maintainer.

---

### Why guardrails run at build time only

Guardrails (`assert_graph_preconditions`, `assert_graph_ready`) are
**only invoked during the master scripts**, never at runtime by the
routing functions. This is a deliberate design choice consistent with
the project's broader build-time precomputation philosophy (see project
readme).

**At build time**, guardrails are essential: they catch a bad import,
a failed topology creation, or a missing index before any user query
can hit a half-broken graph.

Their scope, today, is **structural** — table presence, columns, topology,
indexes, non-empty geometries. Some finer-grained quality guarantees are
*not* yet checked automatically and currently rest on manual preparation in
QGIS: that the network is a single connected component, that snapping was
done at a 1 m tolerance, and that geometries are simple `LineString`s rather
than `MultiLineString`s. The graph is correct — but part of that correctness
comes from the operator's QGIS work, not from the guardrail. In other words,
this engine currently assumes someone who knows how to prepare spatial data
in QGIS; a fully automated import (component merging, geometry normalisation)
is a larger effort left out of the prototype. Extending the "data ready"
guardrail to cover these checks is a known future improvement.

**At runtime**, guardrails would add overhead to every API call for
checks that cannot have changed since the build (the graph is static
between builds). Skipping them is safe because the build pipeline
guarantees that the graph reaching the runtime stage is in a known-good
state.

If the graph were ever to change at runtime (live OSM updates,
incremental imports), the guardrail strategy would need to be revisited.
This is not currently planned.

---

## The Python application

The Python layer (`app/`) exposes the SQL engine over HTTP. It does not
re-implement routing — it opens a database connection, calls the SQL entry
points, maps structured database errors to HTTP status codes, and returns
GeoJSON. The application is a Flask app built from two routing-related
services plus a health check.

### The layered pattern

Each service is organised in the same layers, top to bottom:

```text
Blueprint     HTTP boundary: reads query params, checks presence,
              maps domain exceptions to HTTP status codes
   │
   ▼
Service       Business orchestration: validates the request, calls the
              repository, wraps the result
   │
   ▼
Repository    Database access: runs the SQL, maps psycopg2 errors to
              domain exceptions
   │
   ▼
DTO           Request validation + response serialisation (to GeoJSON)
Model         Domain object (when the service carries Python-side data)
Exceptions    Domain-specific error types
```

**Dependency injection.** The wiring is explicit and flows downward: the
blueprint opens the connection, injects it into the repository, and injects
the repository into the service.

```python
conn    = get_db_conn()
repo    = RouteRepository(conn)
service = RouteService(repo)
```

This keeps each layer testable in isolation: a repository can be exercised
against a database without HTTP, and a service can be given a fake
repository without a database. Exception ordering in the blueprint is
deliberate — specific domain exceptions (`InvalidCoordinatesError`,
`PointOutOfCoverageError`, …) are caught before the generic `except`, so
each maps to its own status code rather than collapsing into a 500.

### Two services, one pattern — a deliberate contrast

Both services (`routes/` and `pois/`) follow the layers above, but they sit
at opposite ends of a spectrum on purpose, to exercise two different ways of
building on the engine.

- **`routes/` — thin over a pure SQL engine.** The route computation lives
  entirely in PL/pgSQL (`export_route_api` → `route_metrics` →
  `dijkstra_snap` → …). Python only validates input, calls one SQL function,
  and returns its GeoJSON. There is no domain `Model`: the database already
  returns the final shape, so the DTO simply wraps it. This is the engine in
  its purest form — the database is the single source of truth and does the
  heavy lifting.

- **`pois/` — application logic on top of the engine.** POI search reuses
  the route the engine produces, then adds a Python-side layer: it searches
  for points of interest within a radius along that route, orders them by
  distance, and serialises them. Here the service does carry a domain `Model`
  (the `POI` dataclass) and an `Enum` (`POICategory`) for validation and
  mapping.

The contrast is intentional. `routes/` shows delegation to the right tool —
let the spatial database do spatial work. `pois/` shows structured
application logic in Python — domain models, validation, transformation —
layered cleanly on top of that same engine. The shared pattern makes both
predictable to read; the difference shows the engine can be consumed either
thinly or with a richer application layer.

### On not factoring the two services together (yet)

The two services duplicate some structure (both have a blueprint, a service,
a repository). Pulling the shared parts into a common base or into `utils/`
is deliberately **not** done yet. With only two services it is too early to
know what is genuinely common versus what merely looks alike — abstracting
now would risk a base class that the next service does not fit. Readable
duplication is preferred over a premature abstraction; the shared parts can
be extracted later, once the pattern has proven stable across more than two
cases.

## Tests

Tests live in `tests/` at the project root, split by kind. The SQL-level
checks that run *inside* the build (graph guardrails, the diametral stress
test) are part of the engine and are covered under *The SQL engine* above;
this section is about the application-level tests that exercise the running
API.

### End-to-end (curl)

A shell suite (`tests/curl/`) drives the live API over HTTP and checks
status codes and response shape across all four endpoints: `/api/route`,
`/api/pois_search`, `/api/coverage`, and the `/api/test_db` health check.
It is the broadest net — it confirms the whole stack (Flask → psycopg2 →
PostGIS → pgRouting) answers correctly end to end. Run it with
`make test-api`.

### Integration (pytest)

A pytest suite (`tests/pytest/`) uses Flask's test client to exercise the
API without a live HTTP server. It currently covers the routing side:

- `/api/route` — missing parameters (400), a known short route (200, with a
  distance assertion), no path (404), and out-of-coverage (422)
- `/api/coverage` — returns a GeoJSON `Polygon` (200)

The POI endpoint is **not yet covered by pytest** — that suite is the next
testing milestone (see project readme roadmap). So the two services are not
at equal robustness today: routing is covered at both the curl and pytest
levels, POI search only at the curl level.

### Health check

`blueprint_health.py` exposes `/api/test_db`, a minimal endpoint that opens
and closes a database connection to confirm connectivity. It sits outside
the Service/Repository pattern on purpose — it has no domain logic, only an
infrastructure probe — and is used both by the curl suite and as a Docker
healthcheck.

## Cross-references

- [`data_model.md`](./data_model.md) — tables, views, indexes, SRID
  strategy, configuration functions
- [`engine_functions.md`](./engine_functions.md) — full PL/pgSQL function
  reference
- [`pipeline.md`](./pipeline.md) — end-to-end ETL from OSM PBF to API
- [`error_codes_sre.md`](./error_codes_sre.md) — structured error tags
  raised by guardrails and routing functions
- [`docker.md`](./docker.md) — service orchestration that runs the
  master scripts
- [`../readme.md`](../readme.md) — project overview, API endpoint reference,
  and roadmap
