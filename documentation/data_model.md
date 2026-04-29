# Data model

This document describes the spatial data structures used by the
`small_routing_engine` — tables, views, indexes, configuration functions,
and the rationale behind their design.

It is intended for developers who need to understand or extend the
database layer, and for reviewers evaluating the project's data design.

For the structure of the SQL files that build and use these objects,
see [`architecture.md`](./architecture.md).
For the routing functions that consume these structures, see
[`engine_functions.md`](./engine_functions.md).

---

## 1. SRID strategy

The project uses two distinct spatial reference systems, each with a
specific role.

| SRID | Role     | Why                                                |
|------|----------|----------------------------------------------------|
| 2154 | Storage  | Projected, metric, accurate over the territory     |
| 4326 | API      | Standard for web mapping and GeoJSON               |

**EPSG:2154** is a projected SRID that yields accurate distances and
areas in meters, which is essential for an engine that uses edge length
as a routing cost.

**EPSG:4326** is the standard SRID for web mapping (Leaflet, MapLibre,
Mapbox) and the canonical SRID for GeoJSON. Coordinates are expressed
in decimal degrees.

**Conversion is centralised in PL/pgSQL.** The routing functions
transform between the two SRIDs at the boundary (snapping API
coordinates inward, exporting GeoJSON outward). Python code never
performs SRID conversion.

The chosen SRIDs are exposed as PL/pgSQL functions
(`routing_graph_srid()` and `routing_api_srid()`) rather than hardcoded
constants, so that a future deployment on a different territory can
change them in one place. See section 7 for details.

### 1.1 Coordinate axis order at the API boundary

The API accepts coordinates in `(lat, lon)` order — the order humans
naturally use when reading or speaking coordinates. PostGIS and most
GIS tooling, however, work in `(lon, lat)` order — the mathematical
convention `(x, y)`.

To avoid carrying this ambiguity through the codebase, the swap from
`(lat, lon)` to `(lon, lat)` happens **explicitly and once**, inside
the snap-to-nearest-node function. After this boundary, every internal
function operates in the GIS-standard `(lon, lat)` order without any
remaining axis-order question. This is the same boundary-conversion
principle applied to SRID, applied here to axis ordering.

---

## 2. Tables

### 2.1 `routes_v1`

The road network used for routing. Each row represents one edge of the
graph, with its geometry, attributes inherited from OpenStreetMap, and
the routing weights consumed by pgRouting.

#### Schema

| Column         | Type                          | Source        | Role                                |
|----------------|-------------------------------|---------------|-------------------------------------|
| `fid`          | `SERIAL PRIMARY KEY`          | Auto          | Edge unique identifier              |
| `osm_id`       | `varchar`                     | OSM           | OpenStreetMap original id           |
| `bicycle`      | `varchar`                     | OSM           | Bicycle access tag                  |
| `cycleway`     | `varchar`                     | OSM           | Cycleway type (lane, track, etc.)   |
| `highway`      | `varchar`                     | OSM           | Road class (primary, residential…)  |
| `lit`          | `varchar`                     | OSM           | Lighting tag (see below)            |
| `maxspeed`     | `varchar`                     | OSM           | Speed limit                         |
| `name`         | `varchar`                     | OSM           | Street name                         |
| `oneway`       | `varchar`                     | OSM           | One-way direction tag               |
| `surface`      | `varchar`                     | OSM           | Surface type (asphalt, gravel…)     |
| `comp`         | `integer`                     | QGIS cleaning | Connected component id              |
| `length_m`     | `double precision`            | Computed      | Edge length in meters (EPSG:2154)   |
| `geom`         | `geometry(LineString, 2154)`  | OSM + cleaning| Edge geometry (EPSG:2154)           |
| `cost`         | `double precision`            | Computed      | Routing weight (forward direction)  |
| `reverse_cost` | `double precision`            | Computed      | Routing weight (reverse direction)  |
| `source`       | `bigint`                      | pgRouting     | Source vertex id (after topology)   |
| `target`       | `bigint`                      | pgRouting     | Target vertex id (after topology)   |

#### Note on `lit`

The OSM `lit` tag is not a strict boolean — its accepted values include
`yes`, `no`, `24/7`, `automatic`, `sunset-sunrise`, and `opening_hours`-
style schedules (e.g. `Mo-Fr 05:00-07:45`). In practice, in this
dataset, the vast majority of populated rows are `yes` or `no`,
which makes the column usable as a near-boolean for current routing
decisions. Edge cases (time-windowed lighting) are rare and not yet
exploited.

#### OSM tag mapping

The OSM-sourced columns reflect the tags carried by each OpenStreetMap
way, preserved as-is during import via `osm2pgsql`. They are not used
yet in routing decisions but are kept available for future
multi-criteria cost models (see section 6).

For example, the `surface` column contains values like `asphalt`,
`paved`, `gravel`, `unpaved`. These will eventually feed cost weighting
(a gravel street is less attractive for a road bike than asphalt).
Today, they are descriptive only.

> **Tag completeness challenge.** Some OSM tags are sparsely populated
> (10% or less of edges), which raises the question of whether they
> are usable as cost inputs at all. This will be assessed once isolated
> components are merged into the graph (parks, disconnected paths,
> etc.) — at which point the completeness picture may shift.

#### Geometric constraints

- `geom` is constrained to `LineString` geometry in EPSG:2154.
- Edges shorter than 1 meter are removed during preprocessing
  (see `04_edges_cleaning.sql`) — they are typically artifacts of
  imperfect snapping during cleaning.
- Edges with `NULL` length are also removed.
- Geometries are simple linestrings (no multilinestrings, no Z/M
  dimensions).

#### Versioning rationale

The `_v1` suffix is intentional. The schema reflects the current
prototype's needs (OSM-only sources, single-component graph, simple
costs). When the project integrates additional data sources or
asymmetric cost models, a `routes_v2` table will be created in
parallel rather than altering `routes_v1` in place. This keeps
deployments backward-compatible and makes it possible to A/B-test
routing changes against historical data.

---

### 2.2 `pois`

Points of interest distributed across the routable territory, served as
a GeoJSON FeatureCollection by the API.

The POI dataset has a different design objective than the routing
network: the goal is **demonstrative, not exhaustive**. The intent is
to validate that displaying typed POIs alongside routes is feasible
without overengineering. As a consequence, the inclusion criteria is
strict:

- **POIs without an OSM `amenity` tag are dropped during preparation.**
  An untagged point cannot be assigned a category and would carry no
  useful information for the user, so it is excluded rather than kept
  as low-quality data.
- POIs are not snapped onto routing edges. They are independent
  geographic features overlaid on the network, not nodes within it.

This is the opposite trade-off from `routes_v1`, where columns with
sparse data are kept (the schema absorbs incompleteness). For POIs,
incomplete records are filtered out (the data is normalised before
storage).

#### Schema

| Column     | Type                          | Source        | Role                              |
|------------|-------------------------------|---------------|-----------------------------------|
| `fid`      | `BIGSERIAL PRIMARY KEY`       | Auto          | POI unique identifier             |
| `osm_id`   | `varchar`                     | OSM           | OpenStreetMap original id         |
| `amenity`  | `varchar`                     | OSM           | OSM amenity tag                   |
| `name`     | `varchar`                     | OSM           | POI name                          |
| `category` | `varchar(20)`                 | Curated       | Functional category (see below)   |
| `geom`     | `geometry(Point, 2154)`       | OSM           | POI location (EPSG:2154)          |

#### Category values

Four categories are currently defined:

| Category         | Examples (OSM amenities)                                   |
|------------------|------------------------------------------------------------|
| `velo`           | bicycle_repair, bicycle_parking, bicycle_rental            |
| `ravitaillement` | drinking_water, supermarket, food-related amenities        |
| `services`       | toilets, pharmacy, post_office                             |
| `culture`        | library, museum, theatre                                   |

Categories are assigned during data preparation (QGIS) by mapping OSM
amenity tags to a coarser, route-relevant taxonomy. This mapping lives
in the source GeoPackage, not in the database — meaning the database
receives already-categorised data.

#### Geometric constraints

- `geom` is constrained to `Point` geometry in EPSG:2154.
- POIs lying outside the project's bounding box are discarded during
  preparation.

---

## 3. Views

Views provide a stable, canonical interface that all routing functions
must use, decoupling the internal table schema from the algorithms that
consume it.

### 3.1 `routing_edges`

```sql
CREATE OR REPLACE VIEW routing_edges AS
SELECT
  fid AS id,
  source,
  target,
  cost,
  reverse_cost,
  geom,
  length_m
FROM public.routes_v1;
```

**Purpose.** Expose the routing-relevant subset of `routes_v1` with the
column names expected by pgRouting algorithms (`id`, `source`, `target`,
`cost`, `reverse_cost`).

**Decoupling rationale.** All routing functions query `routing_edges`,
never `routes_v1` directly. This means:

- `routes_v1` can be replaced or migrated to `routes_v2` without
  modifying any routing function.
- The view enforces a stable contract — only the columns used by
  routing are exposed.
- OSM attributes (highway, surface, etc.) are deliberately excluded
  from the view; they are reachable from the table directly when
  needed for analysis or future cost weighting.

### 3.2 `routing_vertices`

```sql
CREATE OR REPLACE VIEW routing_vertices AS
SELECT
  id,
  the_geom,
  chk
FROM public.routes_v1_vertices_pgr;
```

**Purpose.** Expose the vertex table generated automatically by
`pgr_createTopology` under a stable name.

**Source.** `routes_v1_vertices_pgr` is created by pgRouting during the
graph build. The vertices are the endpoints of every edge, deduplicated
and assigned a unique id. The `the_geom` column holds the vertex
location, and `chk` is a connectivity flag set by pgRouting.

**Decoupling rationale.** Same reasoning as `routing_edges` — if the
underlying table is renamed or replaced, the view absorbs the change.

---

## 4. Indexes

### 4.1 Spatial indexes (GIST)

```sql
CREATE INDEX routes_v1_geom_idx ON public.routes_v1 USING gist (geom);
CREATE INDEX pois_geom_idx      ON public.pois      USING gist (geom);
```

GIST indexes accelerate spatial queries: nearest-neighbor lookups
(`<->`), distance filters (`ST_DWithin`), and bounding-box intersections
(`&&`). They are essential for the snap-to-nearest-node operation that
maps API-supplied coordinates to graph vertices.

### 4.2 B-tree indexes for routing

```sql
CREATE INDEX routes_v1_source_idx ON public.routes_v1 (source);
CREATE INDEX routes_v1_target_idx ON public.routes_v1 (target);
```

pgRouting algorithms scan edges by `source` and `target` repeatedly
during a Dijkstra exploration. B-tree indexes on these columns avoid
sequential scans on the 76k-edge table.

### 4.3 Auto-generated indexes

- The `fid` primary key automatically creates a B-tree index.
- `pgr_createTopology` automatically indexes the `routes_v1_vertices_pgr`
  table (primary key on vertex id, spatial index on `the_geom`).

No manual index is added to `routes_v1_vertices_pgr` — pgRouting handles
its own indexing strategy on the vertices table.

---

## 5. Indexing notes — what is *not* indexed

It is worth noting what is deliberately not indexed:

- **OSM attribute columns** (`highway`, `surface`, `cycleway`, etc.).
  These are not used in current routing queries; indexing them would
  cost write performance during imports for no read benefit.
- **`length_m`**. Used as a cost column, not as a query predicate.
- **`category` on `pois`**. The POI dataset is small (~1000 rows) and
  the API currently returns the full collection without filtering, so
  a B-tree index would be overkill.

These choices are revisitable when (a) OSM attributes start driving
multi-criteria costs, or (b) the POI API gains category filtering.

---

## 6. Routing costs (current model)

The current cost configuration sets `cost = reverse_cost = length_m`,
meaning Dijkstra-family algorithms minimize **distance**, and the graph
is effectively **symmetric** — an edge has the same weight in both
directions.

```sql
UPDATE public.routes_v1
SET cost = length_m,
    reverse_cost = length_m
WHERE length_m IS NOT NULL
  AND (cost IS NULL OR reverse_cost IS NULL);
```

### 6.1 Why this is a deliberate prototype choice

A symmetric graph is the **optimal case** for `pgr_bdDijkstra`
(bidirectional Dijkstra). The algorithm explores the graph from both
endpoints simultaneously, and its efficiency depends on the two
explorations meeting cleanly in the middle. With symmetric costs, the
meeting-point behavior is predictable, and the algorithm achieves its
theoretical ~2x speedup over plain Dijkstra.

This is why the project delivers ~145 ms median response times on
worst-case diametral queries despite operating on a 76k-edge graph
(see project readme).

### 6.2 What changes with real asymmetric costs

Real-world routing requires asymmetric costs:

- **One-way streets**: a forbidden direction should have an infinite
  (or sentinel) reverse cost.
- **Slope from elevation models**: climbing costs more than descending,
  asymmetrically, in proportion to altitude difference.
- **Surface bonuses**: a dedicated cycleway weighs less than a parallel
  vehicle road in the same direction; this asymmetry exists per direction.
- **Cycleway priorities**: certain unidirectional cycle facilities
  produce direction-dependent weights.

When these are introduced, the symmetric assumption breaks, and
`pgr_bdDijkstra` loses its efficiency advantage. The bidirectional
exploration may also become numerically unstable on strongly asymmetric
graphs.

### 6.3 Planned algorithmic transitions

Two directions, both in the project's Later phase:

- **`pgr_dijkstra` + bounding-box pre-filtering**: reduces the candidate
  graph spatially before running classical Dijkstra. Robust to any cost
  asymmetry.
- **`pgr_aStar`**: uses a geographic heuristic (Euclidean distance to
  destination) to prioritize promising nodes. Works with arbitrary edge
  costs; the heuristic remains valid as long as the cost function does
  not produce negative weights.

Both options are documented in the project readme under
"Multi-criteria costs" and "Raster-based costs".

---

## 7. Configuration functions (PL/pgSQL)

Routing constants are exposed as `IMMUTABLE` PL/pgSQL functions rather
than hardcoded literals. This is a deliberate portability choice.

### 7.1 The four configuration functions

```sql
routing_graph_srid()           → 2154
routing_api_srid()             → 4326
routing_topology_tolerance_m() → 1.0
routing_default_speed_kmh()    → 15.0
```

| Function                         | Used in                            |
|----------------------------------|------------------------------------|
| `routing_graph_srid()`           | Length computation, snapping       |
| `routing_api_srid()`             | API coordinate reception, GeoJSON  |
| `routing_topology_tolerance_m()` | `pgr_createTopology` tolerance     |
| `routing_default_speed_kmh()`    | Default ETA when speed not given   |

### 7.2 Why functions, not constants

A future deployment on a different territory (e.g. Belgium with
EPSG:31370, or Switzerland with EPSG:2056) requires changing the storage
SRID. With constants scattered across SQL files, this is an error-prone
search-and-replace. With centralized functions, a single function body
is updated, and every dependent function picks up the change.

The same logic applies to the topology tolerance (which depends on the
local geographic precision of the source data) and the default cycling
speed (which may differ in a denser urban context vs a rural one).

Marking the functions as `IMMUTABLE` allows PostgreSQL to inline them
during query planning, so the abstraction has no runtime cost.

### 7.3 Limitation

SRID portability is not yet **end-to-end tested**. Changing
`routing_graph_srid()` to another value would also require validating
that the source data import paths (osm2pgsql config, ogr2ogr commands)
produce geometries in the new SRID. This is tracked in the readme's
Production readiness phase.

---

## 8. Cross-references

- [`architecture.md`](./architecture.md) — SQL file structure and
  build-time orchestration
- [`engine_functions.md`](./engine_functions.md) — PL/pgSQL functions
  that consume these structures
- [`pipeline.md`](./pipeline.md) — how data gets from OSM PBF into
  these tables
- [`error_codes_sre.md`](./error_codes_sre.md) — structured error tags
  raised by routing functions
- [`docker.md`](./docker.md) — service orchestration that runs the
  build pipeline
