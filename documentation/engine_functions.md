# Functions reference

This document is the reference for the **production routing functions** —
the SQL functions consumed by the Flask API, plus the configuration and
guardrail functions they depend on. Debug and visualisation scripts
(those living in `xx_debug/`) are intentionally out of scope here.

For the build pipeline and where these functions fit in it, see
[`architecture.md`](./architecture.md). For the data they operate on,
see [`data_model.md`](./data_model.md).

---

## Overview / call graph

```
API (Flask repository)
  ├── is_within_coverage(lat, lon)        [x2 — start + end, entry guard]
  │     └── graph_coverage (coverage polygon)
  │
  └── export_route_api(...)               → RETURNS JSON (GeoJSON Feature + output bbox)
        └── route_metrics(...)
              └── dijkstra_snap(...)
                    ├── snap_to_nearest_node(lat, lon)   [x2] → (id, the_geom)
                    ├── compute_routing_bbox(geom_s, geom_t) → performance bbox
                    └── dijkstra_only(start, end, bbox)  → pgr_dijkstra (directed)
```

### Two parallel chains from the API

The Flask repository drives **two independent calls** per route request:

1. **Coverage guard** — `is_within_coverage()` is called twice (start
   point, then end point) *before* any routing. It validates that both
   inputs fall inside the graph's coverage polygon and raises if not.
   This is cheap and fails fast, before the expensive routing work.
2. **Routing** — `export_route_api()` runs the actual route computation
   chain and returns the GeoJSON Feature.

### Standalone / testable independently

- `dijkstra_only()` — core routing, no snapping, no guardrails
- `snap_to_nearest_node()` — coordinate → vertex resolution
- `compute_routing_bbox()` — pure geometric helper

### Configuration (IMMUTABLE constants, called by many functions)

`routing_graph_srid()`, `routing_api_srid()`,
`routing_topology_tolerance_m()`, `routing_default_speed_kmh()`,
`routing_bbox_buffer_ratio()`

### Guardrails (called at build time)

- `assert_graph_preconditions_on(table)` / `assert_graph_preconditions()`
  — pre-build data validation
- `assert_graph_ready_on(...)` / `assert_graph_ready()` — post-build
  graph-state validation

---

## A note on the three bounding boxes

The project uses the word "bbox" in three distinct places. They serve
different purposes and even live in different SRIDs — worth keeping
straight:

| Name | Built by | SRID | Purpose |
|---|---|---|---|
| **Performance bbox** | `compute_routing_bbox()` | 2154 (graph) | Filters edges spatially before Dijkstra explores them, to speed up short urban routes. Internal to the engine. |
| **Coverage polygon** | `compute_graph_bbox.sql` → `graph_coverage` | 4326 (API) | Validates that user input points fall inside the served area. Checked by `is_within_coverage()`. Despite the column name `bbox`, it is a buffered convex hull, not a rectangle. |
| **Output bbox** | `export_route_api()` | 4326 (API) | The envelope of the computed route, emitted in the GeoJSON for front-end map framing. Pure presentation. |

---

## Configuration

### routing_graph_srid()

**Intention**
Centralises the routing graph's SRID in one place. Any function needing
the graph's SRID calls this function instead of hardcoding the value.
Makes a change in SRID transparent for the engine.

**Signature**
```sql
routing_graph_srid() -> integer
```

**Returns**
`2154` (RGF93 / Lambert-93)

**Preconditions**
None.

**Edge cases**
None — `IMMUTABLE` function, constant value.

**Errors**
None.

**Dependencies**
None.

**Why `IMMUTABLE`?**
The value never changes between two calls. `IMMUTABLE` allows PostgreSQL
to inline the value in expressions and use it in indexes — unlike
`STABLE` or `VOLATILE`.

### routing_api_srid()

Same pattern as `routing_graph_srid()`.
Returns `4326` (WGS 84) — web-facing SRID, used for all API inputs and
outputs.

### routing_topology_tolerance_m()

**Intention**
Centralises the topology tolerance (in meters) chosen at graph creation.
The pgRouting `pgr_createTopology()` function needs this value. Keeps the
chosen tolerance transparent and stored in one place only.

**Signature**
```sql
routing_topology_tolerance_m() -> double precision
```

**Returns**
`1.0` — one meter tolerance. Lambert-93 (EPSG:2154) is meter-based, so
this value maps directly to a real-world distance. Would be meaningless
with a degree-based SRID such as 4326.

**Edge cases**, **Errors**, **Dependencies**, **Why `IMMUTABLE`?**
See `routing_graph_srid()`.

### routing_default_speed_kmh()

**Intention**
Centralises the default cycling speed used for travel-time estimation.
Called by `route_metrics()` as a default parameter value — avoids
hardcoding in post-processing.

**Signature**
```sql
routing_default_speed_kmh() -> double precision
```

**Returns**
`15.0` — estimated average cycling speed in km/h. Reasonable default for
urban cycling; can be overridden at call time.

**Edge cases**, **Errors**, **Dependencies**, **Why `IMMUTABLE`?**
See `routing_graph_srid()`.

### routing_bbox_buffer_ratio()

**Intention**
Centralises the buffer ratio used by `compute_routing_bbox()` to enlarge
the performance bounding box around a route.

**Signature**
```sql
routing_bbox_buffer_ratio() -> double precision
```

**Returns**
`0.30` — the performance bbox is enlarged by 30% of the euclidean
distance between the two snapped vertices. Generous enough that the
direct path is rarely clipped, tight enough to still cut the edge set
meaningfully on short routes.

**Edge cases**, **Errors**, **Dependencies**, **Why `IMMUTABLE`?**
See `routing_graph_srid()`.

---

## Pre-processing

### snap_to_nearest_node(lat, lon)

**Intention**
Bridge between user-facing coordinates (EPSG:4326) and the routing graph
(EPSG:2154). Returns the nearest graph vertex — both its id and its
geometry — so routing functions can work from real-world geographic
inputs.

**Signature**
```sql
snap_to_nearest_node(lat double precision, lon double precision)
  -> TABLE (id BIGINT, the_geom geometry(Point, 2154))
```

**Returns**
A single row: the id of the nearest graph vertex and its geometry in
EPSG:2154. The geometry is returned alongside the id so that
`compute_routing_bbox()` can build the performance bbox without
re-querying `routing_vertices`.

Note: input coordinates follow human `lat, lon` order; the function
reorders them to `lon, lat` internally when building the PostGIS point.

**Preconditions**
None required from the caller. The function does **not** call any
guardrail itself — graph-state validation happens at build time via
`assert_graph_ready()`, not on the query path.

**Edge cases**
If input coordinates fall outside the graph's extent, the function still
returns the nearest boundary vertex without error. In production this
case is prevented upstream by `is_within_coverage()`, which rejects
out-of-area points before snapping is ever reached.

**Errors**
None raised directly.

**Dependencies**
`routing_vertices`, `routing_api_srid()`, `routing_graph_srid()`

### compute_routing_bbox(geom_s, geom_t)

**Intention**
Compute the **performance bounding box** used to filter routing edges
before Dijkstra exploration. Built around the two snapped vertices and
enlarged by a buffer proportional to their distance.

**Signature**
```sql
compute_routing_bbox(
  geom_s geometry(Point, 2154),
  geom_t geometry(Point, 2154)
) -> geometry(Polygon, 2154)
```

**Returns**
A polygon in EPSG:2154: the envelope of the two points, buffered by
`ST_Distance(geom_s, geom_t) * routing_bbox_buffer_ratio()` (square
endcaps, mitre joins).

**Preconditions**
Both inputs must be valid points in the graph SRID — satisfied by
`snap_to_nearest_node()`.

**Edge cases**
On long trips the buffered box may exceed the graph extent. This is
acceptable: the spatial filter simply becomes a no-op rather than a
constraint that could lose valid paths. The fallback in `dijkstra_snap()`
covers the rare case where filtering does eliminate the only path.

**Errors**
None.

**Dependencies**
`routing_bbox_buffer_ratio()`

---

## Core routing

### dijkstra_only(start_node, end_node, bbox)

**Intention**
Core routing function. Returns the minimal ordered set of edges needed to
build a route, so it can be wrapped by higher-level functions for
different uses (e.g. future multi-stop routes).

**Signature**
```sql
dijkstra_only(
  start_node BIGINT,
  end_node   BIGINT,
  bbox       geometry DEFAULT NULL
)
```

**Returns**

| Column   | Type                 | Unit | Description                   |
|----------|----------------------|------|-------------------------------|
| seq      | INTEGER              | —    | Step order along the route    |
| edge_id  | BIGINT               | —    | Edge id in `routing_edges`    |
| cost     | DOUBLE PRECISION     | —    | pgRouting internal cost value |
| geom     | geometry(LineString) | —    | Edge geometry in EPSG:2154    |
| length_m | DOUBLE PRECISION     | m    | Edge length in meters         |

**Algorithm**
Uses `pgr_dijkstra(edges_query, start_node, end_node, directed := true)`.
The graph is directed (see [`data_quality.md`](./data_quality.md)
section 3), so `directed := true` is required for one-way streets to be
respected.

When `bbox` is provided, the edges query is filtered with `geom && bbox`
(bounding-box overlap) before Dijkstra runs. When `bbox` is `NULL`,
Dijkstra runs on the full edge set.

**Preconditions**
Needs a valid graph but performs no guardrail check itself — validation
is a build-time concern.

**Edge cases**
None handled here. Boundary handling is upstream (`is_within_coverage`,
snapping); empty-path handling is downstream (`dijkstra_snap`,
`route_metrics`).

**Errors**
None raised directly.

**Dependencies**
`routing_edges`, `pgr_dijkstra`

### dijkstra_snap(lat1, lon1, lat2, lon2)

**Intention**
Wrapper over the core routing function: snaps two geographic points to
graph vertices, applies the performance bbox, and returns the route. The
output is minimal (no GeoJSON).

**Signature**
```sql
dijkstra_snap(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
)
```

**Returns**
Same table as `dijkstra_only()` (see above).

**Behaviour — two-level fallback**
1. Snap both points (`snap_to_nearest_node` x2).
2. Build the performance bbox (`compute_routing_bbox`).
3. Run `dijkstra_only(s, t, bbox)` — the fast, filtered path.
4. If that returns no rows, retry `dijkstra_only(s, t, NULL)` on the full
   graph (the bbox may have clipped the only available path).
5. If the full-graph run *also* returns nothing, the vertices are truly
   disconnected — raise the exception below.

**Preconditions**
Inherited from `snap_to_nearest_node()`.

**Errors**
Only when both the filtered and full-graph attempts find no path:
```sql
'[ROUTING:NO_PATH] no path found between selected points'
USING ERRCODE = 'P0001';
```

**Dependencies**
`snap_to_nearest_node`, `compute_routing_bbox`, `dijkstra_only`

---

## Post-processing

### route_metrics(...)

**Intention**
Post-processing of the routing result: transforms raw edges into
user-facing metrics (distance, estimated time) and assembled geometry in
both SRIDs.

**Signature**
```sql
route_metrics(
  lat1 DOUBLE PRECISION,
  lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION,
  lon2 DOUBLE PRECISION,
  speed_kmh DOUBLE PRECISION DEFAULT routing_default_speed_kmh()
)
```

**Returns**

| Column             | Type                 | Unit | Description                       |
|--------------------|----------------------|------|-----------------------------------|
| total_m            | DOUBLE PRECISION     | m    | Route total length in meters      |
| total_km           | DOUBLE PRECISION     | km   | Route total length in kilometers  |
| estimated_time_min | DOUBLE PRECISION     | min  | Estimated travel time             |
| route_geom_graph   | geometry(LineString) | —    | Route LineString in EPSG:2154     |
| route_geom_api     | geometry(LineString) | —    | Route LineString in EPSG:4326     |

**Preconditions**
Needs a valid route from `dijkstra_snap()`.

**Edge cases**
If `speed_kmh` is NULL or `<= 0`, `estimated_time_min` is returned as
NULL (distance is still computed).

**Errors**
Checks the edge count from `dijkstra_snap()`. If the count is 0, raises:
```sql
'[ROUTING:NO_PATH] no path found between selected points'
USING ERRCODE = 'P0001';
```
> In V1 the disconnected-components case cannot trigger this: one graph,
> one component, clean data. One degenerate case does still reach it
> though — when start and end resolve to the same point, the path has no
> edges and the chain reports `[ROUTING:NO_PATH]`. So the guard is not
> purely preventive today; tightening that case is tracked in the backlog.

**Dependencies**
`dijkstra_snap()`, `routing_graph_srid()`, `routing_api_srid()`

---

## Coverage guard

### is_within_coverage(lat, lon)

**Intention**
Entry guard called by the API before routing. Builds a point from the
user input and verifies it falls inside the graph's coverage polygon.
Raises if not, so out-of-area requests fail fast with a clear error
rather than producing a misleading nearest-boundary route.

**Signature**
```sql
is_within_coverage(lat DOUBLE PRECISION, lon DOUBLE PRECISION) -> VOID
```

**Returns**
Nothing on success (`VOID`). The result is the *absence* of an exception.

**Preconditions**
`graph_coverage` must be populated (it is, at build time, by
`compute_graph_bbox.sql`).

**Edge cases**
If `graph_coverage` is empty, `ST_Within(...)` over zero rows yields NULL
rather than false, so the `IF NOT (...)` guard does not fire and an
out-of-area point can slip through. This is a known limitation tracked in
the backlog; in normal operation the table is always populated by the
build.

**Errors**
```sql
'[COVERAGE:OUT_OF_BOUNDS] Point (%, %) is outside graph coverage area.'
USING ERRCODE = 'P0001';
```

**Dependencies**
`routing_api_srid()`, `graph_coverage`

---

## Export

### export_route_api(...)

**Intention**
Top-level entry point for the API. Computes a route between two
coordinate pairs and returns a single GeoJSON Feature with user-facing
metrics. No psql meta-commands — intended for Flask/psycopg2 consumption.

**Signature**
```sql
export_route_api(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION,
  speed_kmh DOUBLE PRECISION DEFAULT 15.0
) -> JSON
```

**Returns**
A single GeoJSON `Feature` object:

| Field                          | Type                  | Description                         |
|--------------------------------|-----------------------|-------------------------------------|
| `type`                         | `"Feature"`           | GeoJSON type                        |
| `bbox`                         | GeoJSON (4326)        | Envelope of the route (`ST_Envelope`), for front-end map framing |
| `geometry`                     | LineString (4326)     | The route                           |
| `properties.distance_km`       | float, km             | Total route length                  |
| `properties.estimated_time_min`| float, min            | Estimated travel time               |
| `properties.speed_kmh`         | float, km/h           | Speed used for the time calculation |

**Preconditions**
Inherited from dependencies — see `route_metrics()`.

**Edge cases and errors**
None handled in this function; all error handling is inherited from the
chain below it.

**Dependencies**
`route_metrics()`

---

## Guardrails

The guardrails run **at build time**, validating the graph before and
after construction. Each comes in two forms: a generic, testable version
parameterised on a table name (`*_on`), and a production wrapper
hardcoded on the real table.

### assert_graph_preconditions_on(p_table_name) / assert_graph_preconditions()

**Intention**
Validates the minimum viable data state **before** graph creation. Raises
if anything required is missing. `assert_graph_preconditions_on()` is the
testable generic version; `assert_graph_preconditions()` is the
production wrapper hardcoded on `public.routes_v1`.

**Signatures**
```sql
assert_graph_preconditions_on(p_table_name TEXT) -> void
assert_graph_preconditions() -> void
```

**Checks performed (in order)**
1. Table exists
2. Required columns: `geom`, `fid`, `cost`, `reverse_cost`
3. SRID matches `routing_graph_srid()` (EPSG:2154)
4. `length_m` has no NULL values (if the column exists)

**Errors**

| Code | Trigger |
|---|---|
| `GRAPH:TABLE_MISSING` | table doesn't exist |
| `GRAPH:COL_GEOM_MISSING` | `geom` column missing |
| `GRAPH:COL_FID_MISSING` | `fid` column missing |
| `GRAPH:COST_COLS_MISSING` | `cost` or `reverse_cost` missing |
| `GRAPH:GEOM_ALL_NULL` | no non-NULL geometries |
| `GRAPH:SRID_MISMATCH` | SRID ≠ 2154 |
| `GRAPH:LENGTH_M_NULLS` | NULL values in `length_m` |

**Dependencies**
`routing_graph_srid()`

### assert_graph_ready_on(...) / assert_graph_ready()

**Intention**
Post-build guardrail. Validates that the routing graph artifacts exist
and are usable after construction. `assert_graph_ready_on()` is the
testable generic version; `assert_graph_ready()` is the production
wrapper.

**Signature**
```sql
assert_graph_ready() -> void
```

**Checks performed (in order)**
1. `routing_edges` and `routing_vertices` views exist
2. Critical columns exist on both views
3. Both views are non-empty
4. No NULLs in `source`, `target`, `cost`, `reverse_cost`
5. SRID matches `routing_graph_srid()` (EPSG:2154)

**Errors**

| Code | Trigger |
|---|---|
| `GRAPH_STATE:VIEWS_MISSING` | `routing_edges` or `routing_vertices` view missing |
| `GRAPH_STATE:CRITICAL_COLS_MISSING` | critical column missing on either view |
| `GRAPH_STATE:EMPTY` | either view is empty |
| `GRAPH_STATE:TOPOLOGY_NULL` | NULL `source` or `target` in `routing_edges` |
| `GRAPH_STATE:COST_NULL` | NULL `cost` or `reverse_cost` in `routing_edges` |
| `GRAPH_STATE:GEOM_ALL_NULL` | no non-NULL geometries in `routing_edges` |
| `GRAPH_STATE:SRID_MISMATCH` | SRID ≠ 2154 |

**Dependencies**
`routing_graph_srid()`

### Guardrail test suites

Both guardrails have dedicated SQL test suites (in `XX_tests/guardrails/`)
that exercise each error code plus the success case.

- **`assert_graph_preconditions_on`** — a suite of **8 tests**: one per
  error code listed above (table missing, geom/fid/cost columns missing,
  geom all-null, SRID mismatch, length_m nulls) plus a success case on a
  valid table. Each test builds a `TEMP TABLE` in a deliberately broken
  state, calls the guardrail via `PERFORM`, and asserts the expected
  `[CODE]` is raised (failing if no error, or the wrong error, comes
  back).
- **`assert_graph_ready_on`** — a suite of **13 tests**: one per
  `GRAPH_STATE:*` code plus a success case. Because this guardrail
  validates *two* views (edges and vertices), the codes that apply to
  both — `GEOM_ALL_NULL` and `SRID_MISMATCH` — are each tested twice
  (once per view), and `VIEWS_MISSING`, `CRITICAL_COLS_MISSING` and
  `EMPTY` likewise get an edges case and a vertices case. Same
  construction as the preconditions suite (build a temp view in a broken
  state, `PERFORM` the guardrail, assert the expected `[CODE]` is raised),
  with the success case asserting a fully valid edges + vertices pair
  raises nothing.

---

## Cross-references

- [`architecture.md`](./architecture.md) — build pipeline, guardrail
  placement, runtime function chain
- [`data_quality.md`](./data_quality.md) — cost model, directed graph,
  `oneway` handling
- [`data_model.md`](./data_model.md) — table and view schemas
- [`error_codes_sre.md`](./error_codes_sre.md) — full error code catalogue
