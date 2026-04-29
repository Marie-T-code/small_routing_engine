# Small Routing Engine

A geospatial backend project: ETL pipeline from OpenStreetMap to PostGIS,
layered Python API serving GeoJSON, with a bicycle routing engine over
Nevers (France) as the demonstration use case.

Status: functional prototype — see [Roadmap](#roadmap)

---

## Quick demo

```bash
make up
```

Once the pipeline completes, query a route:

```bash
curl "http://localhost:5000/api/route?lat1=46.86025&lon1=3.16577&lat2=47.1189&lon2=3.26215&speed_kmh=15"
```

Response:

```json
{
  "type": "Feature",
  "geometry": { "type": "LineString", "coordinates": [...] },
  "properties": {
    "distance_km": 27.19,
    "estimated_time_min": 108.78,
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

**Geospatial ETL pipeline.** OSM PBF extraction (osmium clip on regional
sources), import via osm2pgsql and ogr2ogr, multi-stage cleaning in QGIS
and PL/pgSQL, merged from two regional sources (Bourgogne + Centre-Val
de Loire) into a single coherent dataset.

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
before any query runs. At query time, bidirectional Dijkstra
(`pgr_bdDijkstra`) runs on a graph that is already complete and validated
— no runtime cleaning, no runtime topology fix, no runtime cost
recomputation. On a 76k-edge single-component graph, this design delivers
~145 ms median response time on worst-case diametral queries (measured
on a development laptop, warm cache, 5-sample median).

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
│  ETL Pipeline (build-time)                                  │
│                                                             │
│  OSM PBF (Geofabrik regional)                               │
│    └─> osmium-tool   (clip to bbox)                         │
│    └─> osm2pgsql     (raw OSM into staging DB)              │
│    └─> QGIS          (snapping, components, cleaning)       │
│    └─> ogr2ogr       (cleaned GPKG into PostGIS)            │
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

Computes a bicycle route between two points using bidirectional Dijkstra
on the precomputed graph.

**Parameters:**

| Param       | Type  | Required | Range       | Description              |
|-------------|-------|----------|-------------|--------------------------|
| `lat1`      | float | yes      | EPSG:4326   | Start latitude           |
| `lon1`      | float | yes      | EPSG:4326   | Start longitude          |
| `lat2`      | float | yes      | EPSG:4326   | End latitude             |
| `lon2`      | float | yes      | EPSG:4326   | End longitude            |
| `speed_kmh` | float | yes      | 10–25       | Cycling speed for ETA    |

> **Why is `speed_kmh` required?** The PL/pgSQL function has a default
> value (15 km/h), but the API layer enforces an explicit value to make
> the request self-documenting: a route returned without an explicit
> speed would carry an ambiguous ETA. The SQL default remains available
> for direct database calls and tests.

**Example:**

```bash
curl "http://localhost:5000/api/route?lat1=46.86025&lon1=3.16577&lat2=47.1189&lon2=3.26215&speed_kmh=15"
```

**Success response (`200 OK`):** GeoJSON Feature with route geometry and metrics.

```json
{
  "type": "Feature",
  "geometry": { "type": "LineString", "coordinates": [...] },
  "properties": {
    "distance_km": 27.19,
    "estimated_time_min": 108.78,
    "speed_kmh": 15
  }
}
```

**Error responses:**

| HTTP | Error code        | Cause                                          |
|------|-------------------|------------------------------------------------|
| 400  | (validation)      | Missing or out-of-range parameters             |
| 404  | `ROUTING:NO_PATH` | No path found between the snapped nodes        |
| 500  | (unexpected)      | Internal error                                 |

---

### `GET /api/pois`

Returns the complete points-of-interest dataset as a GeoJSON FeatureCollection.

```bash
curl http://localhost:5000/api/pois
```

**Success response (`200 OK`):** GeoJSON FeatureCollection with typed
categories (`velo`, `ravitaillement`, `services`, `culture`).

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [...] },
      "properties": { "category": "velo", "name": "..." }
    }
  ]
}
```

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
make help        # list available commands
make fast        # restart without rebuilding images
make down        # stop services
make reset       # stop and clean up network (use after a crash — see docker.md)
make re          # full restart (down + up)
```

---

## Roadmap

The project follows a 5-month maturation plan, from functional prototype
to production-ready service.

### Now (in progress)

- Routes module curl test suite
- Testable version of the graph guardrails (`assert_graph_ready`)
- Bounding box pre-filtering on routing (with dedicated error codes)
- Bounding box visualization on the frontend
- Minimal Leaflet frontend

### Next (committed, ordered)

1. **Test infrastructure** — pytest + testcontainers for SQL
2. **Type discipline** — full typing + Pydantic v2 migration
3. **API & infra modernization** — Flask → FastAPI, Compose v2, recent
   PostgreSQL (currently pinned to PG 16 for compatibility)
4. **Performance** — connection pooling, query optimization
5. **Production readiness** — deployment, observability, security basics

### Later (exploration)

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

- **Single connected component.** The routing engine operates on the
  largest connected component of the cleaned road network. Isolated
  components are discarded during preprocessing. Automated component
  merging is in the [Later](#later-exploration) section.
- **Single SRID strategy.** EPSG:2154 is hardcoded for storage; deploying
  on a different territory currently requires editing the SRID
  configuration function. SRID portability is part of the production
  readiness phase.
- **No automated test suite.** The graph guardrails enforce build-time
  consistency, but no Python-level test suite exists yet. pytest +
  testcontainers is the first item of the [Next](#next-committed-ordered)
  phase.
- **No connection pooling.** Each API request opens a new psycopg2
  connection. Acceptable for prototype load; planned for the performance
  phase.
- **No frontend yet.** The API serves GeoJSON ready for any client; a
  minimal Leaflet frontend is in progress.
- **Cycling speed range.** The API enforces 10–25 km/h to reflect typical
  urban cycling. Other ranges (e-bike, sport) would require recalibrating
  cost weights.

---

## License

MIT License — see [LICENSE](./LICENSE) for details.
