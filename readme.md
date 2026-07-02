![tests](https://github.com/Marie-T-code/small_routing_engine/actions/workflows/tests.yml/badge.svg)

Note (July 2026): Following a heatwave-induced delay, several fixes and improvements (testing, frontend setup, ...) were made, committed, and documented in [`to_do.md`](./documentation/to_do.md) — but are not yet reflected in this README. A full README update is planned once the raster service is complete (~mid-July).

# Small Routing Engine

A geospatial backend project: a semi-automated ETL pipeline from
OpenStreetMap to PostGIS (see [note on automation scope](#what-this-project-demonstrates)),
a layered Python API serving GeoJSON, with a bicycle routing engine over
Nevers (France) as the demonstration use case.

Status: functional prototype — see [Roadmap](#roadmap)

---

## Quick demo

```bash
make up
```

Once the pipeline completes, query a route:

```bash
curl "http://localhost:5000/api/route?lat1=46.9862&lon1=3.1887&lat2=46.9877&lon2=3.1656&speed_kmh=15"
```

Response:

```json
{
  "type": "Feature",
  "bbox": {
    "type": "Polygon",
    "coordinates": [[[3.1655987, 46.9833385], ...]]
  },
  "geometry": {
    "type": "LineString",
    "coordinates": [[3.1885301, 46.9859217], ...]
  },
  "properties": {
    "distance_km": 2.3,
    "estimated_time_min": 9.21,
    "speed_kmh": 15
  }
}
```

> Requires Docker, Docker Compose, GNU Make, and the dataset + `.env` file.
> See [Quick start](#quick-start) for full setup, or run `make help` for available commands.

---

## Why this project exists

Most routing engines fall into two categories: black boxes operated by
large platforms (Google Directions, Mapbox), or open-source solutions
(OSRM, GraphHopper) that handle planetary-scale routing well but treat
the underlying data as a sealed input — local mobility data, ground-truth
corrections, or cycling-association feedback are difficult to integrate
without forking the engine itself.

This project explores a third path: a self-hosted routing stack with full
data ownership, small enough to be maintained by a single team, built on
tools that a municipality, a small consultancy, or an environmental NGO
could realistically operate and adapt to their territory.

Bicycle routing in Nevers is the demonstration use case — chosen because
it requires real spatial reasoning (snapping, multi-criteria costs,
data quality assessment) without the operational weight of a national-scale
deployment.

---

## What this project demonstrates

**Geospatial ETL pipeline.** OSM PBF extraction with osmium, merged from
two regional sources (Bourgogne + Centre-Val de Loire), explored and
cleaned in QGIS, then imported into PostGIS where the routing graph and
its supporting tables are built and cleaned in PL/pgSQL.

> **Note on automation scope.** Data *preparation* is manual; engine
> *construction* is automated. OSM extraction (`osmium` clip/merge),
> staging import, and pre-cleaning in QGIS are done **by hand** —
> deliberately, to inspect the data in QGIS before committing to any
> filter. From `ogr2ogr` onward, everything is automated: a Docker loader
> imports the cleaned GeoPackages into PostGIS, then the SQL masters run
> end-to-end (cost configuration, `pgr_createTopology`, routing views and
> functions, build-time guardrails, table cleanup) — a single `make up`
> builds the whole engine. Automating this upstream data-preparation half
> is a [long-term goal](#long-term-goals-once-a-service-runs-in-production);
> see [`pipeline.md`](./documentation/pipeline.md) for the step-by-step.

**Spatial data modeling.** Two domain datasets (road network, points of
interest) with explicit SRID strategy (EPSG:2154 storage, EPSG:4326 API),
spatial indexes, derived views for graph topology, typed POI categories.

**Database as source of truth.** Routing logic in PL/pgSQL (Dijkstra
orchestration, snapping, metrics export), configuration centralised in
SQL functions, pre-conditions and post-conditions on graph state
enforced at build time. Python orchestrates and exposes — it does not
re-implement.

**Build-time precomputation for sub-second queries.** Edge weights, graph
topology, vertex tables and validation are all computed at build time,
before any query runs. At query time, Dijkstra (`pgr_dijkstra`) runs on a
graph that is already complete and validated — no runtime cleaning, no
runtime topology fix, no runtime cost recomputation.

The graph is **directed**: one-way streets are encoded per edge through
pgRouting's `cost` / `reverse_cost` pair, following pgRouting's convention
where a negative cost means the edge is not traversable in that direction.
A two-way street carries `cost = reverse_cost = length_m`; a one-way street
carries `length_m` in its allowed direction and `-1` in the other.
`pgr_dijkstra` is called with `directed := true`, so directionality lives
in the graph data rather than in the algorithm.

On a 76k-edge single-component graph, this design keeps queries sub-second
across Nevers and a ~15 km radius — from ~68 ms on a short urban route to
~258 ms on a ~33 km diametral query (development laptop, warm cache, mean
of 4–5 runs).

**Layered Python API.** Flask blueprint over Service / Repository / DTO /
Exceptions, structured error codes mapped to HTTP responses, GeoJSON
output ready for frontend consumption.

---

## Stack

| Layer    | Tools                                                      |
|----------|------------------------------------------------------------|
| Data     | PostgreSQL 16, PostGIS 3.4, pgRouting                      |
| Pipeline | osmium-tool, osm2pgsql, ogr2ogr, QGIS                      |
| API      | Python 3.11, Flask, psycopg2-binary                        |
| Infra    | Docker Compose v1-compatible (`version: '3.9'`), GNU Make  |
| Formats  | OSM PBF, GeoPackage, GeoJSON                               |
| SRID     | EPSG:2154 (storage), EPSG:4326 (API)                       |

> **Why these versions, not the latest?** This stack is deliberately
> chosen to remain deployable on modest hardware — 5-year-old laptops,
> small VPS, systems without recent Docker Desktop. It directly serves
> the project's thesis: tools that small organizations can actually run.
> Version upgrades are part of the [roadmap](#roadmap).

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Data preparation  (manual, one-off — see note above)       │
│                                                             │
│  OSM PBF (Geofabrik regional)                               │
│    └─> osmium-tool   (clip to bbox, merge)        [manual]  │
│    └─> osm2pgsql     (raw OSM into staging DB)     [manual] │
│    └─> QGIS          (explore, clean, components)  [manual] │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Engine build  (automated — `make up`)                      │
│    └─> ogr2ogr       (cleaned GPKG into PostGIS)    [auto]  │
│        + SQL masters (graph, functions, guardrails)[auto]   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Database (source of truth)                                 │
│                                                             │
│  Tables:    routes_v1, pois                                 │
│  Views:     routing_edges, routing_vertices                 │
│  Functions: PL/pgSQL — config, snap, dijkstra, metrics,     │
│             export, guardrails (pre/post conditions)        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Python API (request/response)                              │
│                                                             │
│  Blueprint  → HTTP routing, error mapping                   │
│  Service    → orchestration, validation                     │
│  Repository → DB calls, query parameters                    │
│  DTO        → request/response shapes                       │
│  Exceptions → typed errors mapped to HTTP codes             │
└─────────────────────────────────────────────────────────────┘
```

Detailed documentation:
- [`pipeline.md`](./documentation/pipeline.md) — full ETL walkthrough
- [`data_model.md`](./documentation/data_model.md) — tables, views, SRID strategy
- [`engine_functions.md`](./documentation/engine_functions.md) — PL/pgSQL function reference
- [`docker.md`](./documentation/docker.md) — service orchestration
- [`error_codes_sre.md`](./documentation/error_codes_sre.md) — structured error tags

---

## API endpoints

### `GET /api/test_db`

Health check. Returns `200 OK` if the API can reach the database.

```bash
curl http://localhost:5000/api/test_db
```

---

### `GET /api/route`

Computes a bicycle route between two points using Dijkstra (`pgr_dijkstra`)
on the precomputed directed graph. One-way streets are respected through
per-edge `reverse_cost`.

**Parameters:**

| Param       | Type  | Required | Range       | Description              |
|-------------|-------|----------|-------------|--------------------------|
| `lat1`      | float | yes      | EPSG:4326   | Start latitude           |
| `lon1`      | float | yes      | EPSG:4326   | Start longitude          |
| `lat2`      | float | yes      | EPSG:4326   | End latitude             |
| `lon2`      | float | yes      | EPSG:4326   | End longitude            |
| `speed_kmh` | float | yes      | `(10, 25]`  | Cycling speed for ETA    |

> **Why is `speed_kmh` required?** The PL/pgSQL function has a default
> value (15 km/h), but the API layer enforces an explicit value to make
> the request self-documenting: a route returned without an explicit
> speed would carry an ambiguous ETA. The SQL default remains available
> for direct database calls and tests.

**Example:**

```bash
curl "http://localhost:5000/api/route?lat1=46.9862&lon1=3.1887&lat2=46.9877&lon2=3.1656&speed_kmh=15"
```

**Success response (`200 OK`):** GeoJSON Feature with route geometry and metrics.

```json
{
  "type": "Feature",
  "bbox": {
    "type": "Polygon",
    "coordinates": [[[3.1655987, 46.9833385], ...]]
  },
  "geometry": {
    "type": "LineString",
    "coordinates": [[3.1885301, 46.9859217], ...]
  },
  "properties": {
    "distance_km": 2.3,
    "estimated_time_min": 9.21,
    "speed_kmh": 15
  }
}
```

> **About `bbox`.** This is the axis-aligned envelope of the returned
> route (`ST_Envelope`), handy for fitting a map to the result. It is the
> bounding box *of one route* — distinct from the graph coverage area
> returned by [`/api/coverage`](#get-apicoverage), which follows the graph
> edges. Coordinates follow GeoJSON order: `[longitude, latitude]`.

**Performance benchmarks**


Measured on a local environment (Docker Compose), `pgr_dijkstra` on the
directed graph, PostgreSQL warm cache, mean of 4–5 runs.

| Route | Distance | Avg response time |
|-------|----------|-------------------|
| Short (Nevers ~2 km) | 2.3 km | ~68 ms |
| Long (Nevers ~33 km) | 33.2 km | ~258 ms |

Response time scales sub-linearly with distance thanks to a preprocessing
bounding box that restricts the edges Dijkstra explores to the area around
the two endpoints. On short routes the box is small and the speedup is
large; on long diametral routes the box approaches the full graph extent,
so the filter naturally becomes a no-op (still sub-second here). A separate
safety mechanism handles correctness rather than speed: if the bbox-filtered
search finds no path, `dijkstra_snap` retries once on the full graph before
concluding `ROUTING:NO_PATH` — so the optimization can never cause a missed
route.

**Error responses:**

| HTTP | Error code               | Cause                                                       |
|------|--------------------------|-------------------------------------------------------------|
| 400  | (validation)             | Missing coordinates, or `speed_kmh` outside `(10, 25]`      |
| 422  | `COVERAGE:OUT_OF_BOUNDS` | Point is outside graph coverage area                        |
| 404  | `ROUTING:NO_PATH`        | No path found between selected points                       |
| 500  | (unexpected)             | Internal error                                              |

Build-time guardrail errors (graph preconditions and state, all returning
500) are not user-facing and are documented separately in
[`error_codes_sre.md`](./documentation/error_codes_sre.md).

---

### `GET /api/coverage`

Returns the area covered by the routing graph, as a GeoJSON `Polygon`.
A point outside this area cannot be routed: `/api/route` rejects it with
`422 COVERAGE:OUT_OF_BOUNDS` (for example, coordinates in Paris fall well
outside the Nevers graph). A frontend can use this polygon to constrain
where users are allowed to click.

The polygon is the **convex hull of the graph's nodes, buffered by a small
margin** (`ST_Buffer(ST_ConvexHull(...))`) — it follows the real extent of
the network rather than a bounding rectangle. The buffer keeps points
sitting right on the network edge from being wrongly rejected.

**Example:**

```bash
curl "http://localhost:5000/api/coverage"
```

**Success response (`200 OK`):** a bare GeoJSON `Polygon` (not a `Feature`).

```json
{
  "type": "Polygon",
  "coordinates": [[[3.153735269, 46.846505952], ...]]
}
```

**Error responses:**

| HTTP | Cause                                            |
|------|--------------------------------------------------|
| 500  | Internal error (e.g. `graph_coverage` is empty)  |

---

### `GET /api/pois_search`

Finds points of interest **along a computed route**. The endpoint first
computes the bicycle route between the two points, then returns POIs of the
requested category lying within `radius_m` of that route, ordered by
distance to it. This is route-aware search, not a radius around a single
point.

**Parameters:**

| Param       | Type  | Required | Range / values                          | Description                  |
|-------------|-------|----------|------------------------------------------|------------------------------|
| `lat_start` | float | yes      | EPSG:4326                                | Start latitude               |
| `lon_start` | float | yes      | EPSG:4326                                | Start longitude              |
| `lat_end`   | float | yes      | EPSG:4326                                | End latitude                 |
| `lon_end`   | float | yes      | EPSG:4326                                | End longitude                |
| `category`  | str   | yes      | `bike`, `culture`, `services`, `catering`| POI category to search       |
| `radius_m`  | float | yes      | >10 and ≤1000                            | Search radius around the route (meters) |

> **Note on category values.** The API currently accepts the English enum
> values above. The underlying dataset stores French category labels
> (`velo`, `ravitaillement`, `services`, `culture`); this mismatch is a
> known limitation, scheduled to be resolved in the near term. Until then,
> use the English values.

**Example:**

```bash
curl "http://localhost:5000/api/pois_search?lat_start=46.9862&lon_start=3.1887&lat_end=46.9877&lon_end=3.1656&category=catering&radius_m=200"
```

**Success response (`200 OK`):** GeoJSON FeatureCollection. Each feature
carries its category, amenity type, name, and distance to the route,
ordered by distance.

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [3.1730732, 46.9870702] },
      "properties": {
        "name": "La Panade",
        "amenity": "fast_food",
        "category": "catering",
        "distance_m": 106.21
      }
    }
  ]
}
```

**Error responses:**

| HTTP | Error code        | Cause                                              |
|------|-------------------|----------------------------------------------------|
| 400  | (validation)      | Missing parameters, invalid category, or `radius_m` outside `(10, 1000]` |
| 404  | `ROUTING:NO_PATH` | No route found between the two points              |
| 500  | (unexpected)      | Internal error                                     |

> **Note.** Unlike `/api/route`, this endpoint does not pre-validate that
> the endpoints fall within the graph coverage area, so it does not return
> `422 COVERAGE:OUT_OF_BOUNDS`. An out-of-coverage request instead surfaces
> as `404 ROUTING:NO_PATH` (the distant points snap to nodes with no path
> between them). Aligning the two endpoints is a known item, scheduled with
> the POI test pass.

---

## Project layout

```text
small_routing_engine/
├── app/                      # Flask API (Python, layered OOP)
│   ├── routes/               # Routing module (blueprint, service, repo, dto)
│   ├── pois/                 # POI module (blueprint, service, repo, dto)
│   ├── utils/                # Shared helpers (db_errors, etc.)
│   ├── config.py             # DB connection, environment loading
│   └── app.py                # Flask app entry point
│
├── tests/                    # Test suites
│   ├── curl/                 # End-to-end API tests (shell)
│   └── pytest/               # Integration tests (Flask test client)
│
├── DB/                       # PostGIS image build context + init scripts
│   └── init_db/              # Auto-run on first DB startup
│
├── SQL/                      # All routing logic (PL/pgSQL) — see pipeline.md
│
├── docker/                   # Service-specific build contexts
│   ├── loader/               # ogr2ogr + import scripts
│   └── builder/              # SQL master runner
│
├── DATA/                     # Cleaned datasets (gitignored)
│   └── clean/                # *.gpkg files for import
│
├── documentation/            # Detailed project docs
├── exports/                  # Database exports / debug outputs
│
├── docker-compose.yaml       # Service orchestration
├── Makefile                  # Project commands (run `make help`)
├── .gitattributes            # Cross-platform line-ending policy (LF)
├── .env                      # Environment variables (gitignored)
└── readme.md                 # This file
```

---

## Quick start

### Prerequisites

- Docker
- Docker Compose
- GNU Make
- ~2 GB free disk space (mostly Docker images; dataset is only ~34 MB)

### 1. Clone the repository

```bash
git clone https://github.com/Marie-T-code/small_routing_engine
cd small_routing_engine
```

### 2. Get the data and environment file

The cleaned datasets and `.env` template are not stored in the repository.
Download them here:

[**Download `.env` and cleaned `.gpkg` files**](https://mega.nz/folder/u1RVmZoJ#nld-LyYyCG1GYW-tYga81w)

Place them as follows:

```text
small_routing_engine/
├── .env                              # ← project root
└── DATA/
    └── clean/
        ├── nevers_clean.gpkg          # ← road network
        └── nevers_clean_points.gpkg   # ← points of interest
```

### 3. Build and run

```bash
make up
```

This will:
- build the PostGIS database image
- import the road network and POI data
- run all SQL masters (config, graph build, routing functions, guardrails)
- start the Flask API

The API is then available at `http://localhost:${FLASK_PORT}` (default: `5000`).

### 4. Verify

```bash
curl http://localhost:5000/api/test_db
```

Expected response:

```json
{
  "message": "Database connection is a success !",
  "status": "success"
}
```

If something goes wrong, see [`docker.md`](./documentation/docker.md) for service troubleshooting.

### Useful commands

```bash
make up          # build and start the full pipeline — use this first
make fast        # start without rebuilding images (after first run)
make down        # stop services
make reset       # stop and clean up network (use after a crash — see docker.md)
make re          # quick restart (reset + fast)
make psql        # open a psql session in the db container
make test-api    # run the curl end-to-end test suite
make help        # list available commands
```

---

## Roadmap

This repository is scoped as a functional prototype. Hardening it for
production is a deliberate next step in a separate fork, and broader engine
features come later still.

### Now: closing out this project

- POI module: pytest suite + finish integration tests, get the full suite green
- SQL-layer testing: testcontainers for the PostGIS/pgRouting layer
- CI/CD: GitHub Actions running the suite in a dedicated Docker service
- Minimal Leaflet frontend

### Beyond: continued in a forked project

Once this prototype is complete, the production-oriented evolution moves to
a separate fork: full typing + Pydantic v2, Flask → FastAPI migration,
connection pooling and query optimization, and deployment with observability
and security.

### Long-term goals: once a service runs in production

Engine-level features to explore once there is a live service to build on:

- Multi-criteria costs (surface, lighting, cycleways)
- Raster-based costs (altitude, slope from elevation models)
- Smart contextual data (e.g. street lighting active by time and city,
  when local data is available)
- User feedback loop on routes (CRUD for reporting and reviewing
  problematic itineraries — closing the gap between routing output and
  ground truth)
- Personal cycling profile (browser-stored): preferred mode, route
  history, self-set challenges, progress tracking — keeping user data
  on the user's device by design, no server-side account
- Frontend evolution: migrate from Leaflet/vanilla JS to MapLibre with a
  modern framework (vector tiles, 3D foundation, framework ecosystem)
- 3D route visualization with LIDAR HD (IGN open data)
- Isochrone / accessibility services
- Multi-profile routing (different bike user personas)
- Automated component merging
- Multimodal routing (bike + transit)
- Geocoding input (address → coordinates → snap → routing)
- Parallel route computation (`asyncio.gather` over multiple destinations)

---

## Known limitations

This is a functional prototype. Current scope:

- **Partial one-way coverage.** One-way streets are encoded via pgRouting's
  `cost` / `reverse_cost` convention, but the cost configuration currently
  recognizes only the OSM value `oneway=yes` (plus `-1` for reversed
  one-ways). The equivalent forms `oneway=true` and `oneway=1`, present in
  the dataset, are not yet normalized and fall through to the two-way case —
  meaning a small number of one-way segments may be allowed against their
  legal direction during path search. Tracked in the backlog; normalization
  is scheduled for the data-quality pass.
- **Single connected component.** The routing engine operates on the
  largest connected component of the cleaned road network. Isolated
  components are discarded during preprocessing. Automated component
  merging is a [long-term goal](#long-term-goals-once-a-service-runs-in-production).
- **Single SRID strategy.** EPSG:2154 is hardcoded for storage; deploying
  on a different territory currently requires editing the SRID
  configuration function. SRID portability belongs to the production
  hardening done in the [forked project](#beyond-continued-in-a-forked-project).
- **Test coverage still partial.** Build-time graph guardrails, an
  end-to-end curl suite, and a pytest integration suite for the routes and
  coverage endpoints (status 200/400/404/422) are all in place. Still
  missing: pytest for the POI endpoint and testcontainers for the SQL
  layer — both in the [Now](#now-closing-out-this-project) list.
- **No connection pooling.** Each API request opens a new psycopg2
  connection. Acceptable for prototype load; pooling is part of the
  production hardening done in the
  [forked project](#beyond-continued-in-a-forked-project).
- **No frontend yet.** The API serves GeoJSON ready for any client; a
  minimal Leaflet frontend is in progress.
- **Cycling speed range.** The API accepts `speed_kmh` in `(10, 25]` to
  reflect typical urban cycling. Speed does not affect routing itself —
  edge costs are distances (`length_m`), so the path is identical at any
  speed; the value only scales the ETA computed after routing. The bounds
  are an input guard against implausible or unsafe ETA values, not a
  routing constraint.

---

## License

MIT License — see [LICENSE](./LICENSE) for details.
