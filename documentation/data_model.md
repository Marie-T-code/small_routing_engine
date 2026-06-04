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

One stored geometry is the deliberate exception to the "storage in 2154"
rule: `graph_coverage.bbox` is kept in 4326, because it is compared
directly against incoming API coordinates rather than used in any metric
computation (see section 2.3).

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
- POIs are not snapped onto routing edges. They remain independent
  geographic features, not nodes within the graph. The POI *service*,
  however, does not return the whole collection: it searches for POIs
  **along a computed route**, within a radius, filtered by category
  (see below).

This is the opposite trade-off from `routes_v1`, where columns with
sparse data are kept (the schema absorbs incompleteness). For POIs,
incomplete records are filtered out (the data is normalised before
storage).

#### How the POI service queries this table

The POI repository (`find_pois_along_route`) does **not** read `pois`
in isolation. It computes a route first, then selects POIs near that
route:

- it `CROSS JOIN`s `route_metrics(...)` to obtain the route geometry,
- keeps POIs within `radius_m` of that geometry via
  `ST_DWithin(p.geom, route_geom_graph, radius_m)`,
- filters on a **mandatory** `category` (a `POICategory` enum value),
- orders results by distance to the route.

Two consequences worth noting:

- The POI search **depends on routing**. It runs `route_metrics()`, so
  it inherits routing errors — including `[ROUTING:NO_PATH]`, which the
  repository re-maps to a POI-specific exception.
- It does **not** call `is_within_coverage()`, unlike the route service.
  An out-of-area POI search therefore surfaces as a routing error rather
  than a clean coverage error — a known gap to align during the POI test
  pass.

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

### 2.3 `graph_coverage`

A single-row table holding the **coverage polygon** of the routable
area. It exists so the API can reject out-of-area requests cheaply,
before any routing work, rather than returning a misleading
nearest-boundary route.

#### Schema

| Column | Type                       | Source   | Role                          |
|--------|----------------------------|----------|-------------------------------|
| `id`   | `SERIAL PRIMARY KEY`       | Auto     | Row identifier                |
| `bbox` | `geometry(Polygon, 4326)`  | Computed | Coverage polygon (EPSG:4326)  |

#### How it is built

Populated at build time by `compute_graph_bbox.sql`, which is **not** a
plain rectangle despite the column name `bbox`:

```sql
TRUNCATE graph_coverage;
INSERT INTO graph_coverage (bbox)
SELECT ST_Transform(
         ST_Buffer(ST_ConvexHull(ST_Collect(the_geom)), 500),
         routing_api_srid()
       )
FROM routing_vertices;
```

It takes the convex hull of every graph vertex, buffers it by 500 meters
(the vertices are in EPSG:2154, so the buffer is metric), then transforms
the result to EPSG:4326 for storage. The convex hull hugs the real served
area more tightly than an axis-aligned rectangle would, and the buffer
gives a small tolerance at the edges.

Note the SRID: this is the only stored geometry in **4326**, because it is
compared directly against API-supplied coordinates (also 4326) by
`is_within_coverage()`. It is the "coverage polygon" in the three-bounding-
box distinction described in
[`engine_functions.md`](./engine_functions.md).

#### Consumed by

`is_within_coverage(lat, lon)` — the entry guard called by the route
service before snapping (see
[`engine_functions.md`](./engine_functions.md)). The POI service does
**not** call this guard, which is a known gap (an out-of-area POI search
currently surfaces as a routing error rather than a coverage error).

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
(`&&`). The index on `routes_v1.geom` serves the snap-to-nearest-node
operation; the index on `pois.geom` serves the `ST_DWithin` proximity
filter in the POI service (`find_pois_along_route`).

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
- **`category` on `pois`**. The POI service does filter on `category`
  (`WHERE p.category = %s`), so this is a real query predicate — but the
  dataset is small (~1000 rows) and each search is already spatially
  narrowed by `ST_DWithin` against the route before the category filter
  applies. On a result set that small, a B-tree index on `category`
  brings no measurable benefit. This is the choice to revisit first if
  the POI table grows substantially.

These choices are revisitable when (a) OSM attributes start driving
multi-criteria costs, or (b) the POI API gains category filtering.

---

## 6. Routing costs — structural view

This section covers *how* the cost columns are stored and populated. The
*rationale* behind the cost model — why distance-only, why a directed
graph, what the trade-offs are — lives in
[`data_quality.md`](./data_quality.md) section 3, to avoid duplicating it
here.

### 6.1 How the columns are populated

`cost` and `reverse_cost` are derived from `length_m`, with directionality
encoded through the OSM `oneway` tag and pgRouting's `-1` sentinel
convention (`03_costs_config.sql`):

```sql
UPDATE public.routes_v1
SET cost =
  CASE WHEN oneway = '-1' THEN -1 ELSE length_m END,
    reverse_cost =
  CASE WHEN oneway = 'yes' THEN -1 ELSE length_m END
WHERE length_m IS NOT NULL;
```

A `-1` value marks a direction as not traversable. This makes the graph
**directed**, not symmetric: a two-way edge carries `length_m` in both
columns, while a one-way edge carries `-1` in the forbidden direction.

The graph is consumed by `pgr_dijkstra` with `directed := true`. Distance
is the only optimisation criterion in the current prototype.

> **Known limitation.** The `CASE` expressions only recognise `'yes'` and
> `'-1'`; the OSM variants `'true'` and `'1'` fall through and are treated
> as two-way. See [`data_quality.md`](./data_quality.md) section 3.1 for
> the full explanation and the fix path.

### 6.2 The OSM attribute columns are not costs (yet)

The descriptive OSM columns (`surface`, `lit`, `cycleway`, `highway`,
`maxspeed`, `bicycle`) are stored but do not currently feed the cost
function. They are kept for a future multi-criteria cost model — see
section 2.1 (OSM tag mapping) and [`data_quality.md`](./data_quality.md)
section 3.2.

### 6.3 Planned algorithmic transition

The current engine already runs `pgr_dijkstra` with a bounding-box
pre-filter on the edge set (see
[`engine_functions.md`](./engine_functions.md), `compute_routing_bbox`
and `dijkstra_only`), which is robust to any cost asymmetry — so the
directed model above is already supported algorithmically.

The remaining roadmap item is **`pgr_aStar`**: a geographic heuristic
(euclidean distance to destination) to prioritise promising nodes. It
works with arbitrary edge costs as long as the cost function produces no
negative weights, which would pair well with the multi-criteria model
once it lands. This is documented in the project readme.

---

## 7. Configuration functions (PL/pgSQL)

Routing constants are exposed as `IMMUTABLE` PL/pgSQL functions rather
than hardcoded literals. This is a deliberate portability choice.

### 7.1 The five configuration functions

```sql
routing_graph_srid()           → 2154
routing_api_srid()             → 4326
routing_topology_tolerance_m() → 1.0
routing_default_speed_kmh()    → 15.0
routing_bbox_buffer_ratio()    → 0.30
```

| Function                         | Used in                            |
|----------------------------------|------------------------------------|
| `routing_graph_srid()`           | Length computation, snapping       |
| `routing_api_srid()`             | API coordinate reception, GeoJSON  |
| `routing_topology_tolerance_m()` | `pgr_createTopology` tolerance     |
| `routing_default_speed_kmh()`    | Default ETA when speed not given   |
| `routing_bbox_buffer_ratio()`    | Performance bbox sizing in `compute_routing_bbox` |

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
