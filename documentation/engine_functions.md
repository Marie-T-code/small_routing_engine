# Functions reference

## Overview / call graph
### Entry points (called by the Flask API)
export_route_api()
  └── route_metrics()
      └── dijkstra_snap() [x2]
            └── dijkstra_only()
            └── snap_to_nearest_node

### Standalone / testable independently
dijkstra_only()
snap_to_nearest_node()

### Configuration (no dependencies, called by multiple functions)
routing_graph_srid()
routing_api_srid()
routing_topology_tolerance_m()
routing_default_speed_kmh()

### Guardrails 
assert_graph_preconditions_on() (called at build only, testable version)
assert_graph_ready() (**WIP**: for now called at every queue, in the future: testable version and called at build only)


## Configuration
### routing_graph_srid()

**Intention**
Centralises the routing graph's SRID in one place. 
Any function needing the graph's SRID calls this function instead of harcoding the value. Makes a change in SRID transparent for the engine. 

**Signature**
```SQL
routing_graph_srid() -> integer
```

**Returns**
`2154`(RGF93 / Lambert-93)

**Preconditions**
None.

**Edge cases**
None - `IMMUTABLE`function, constant value

**Errors**
None.

**Dependencies**
None. 

**Why `IMMUTABLE`?**
The value never changes between two calls. `IMMUTABLE` allows PostgreSQL to inline said value in the expressions and use it in indexes - contrary to `STABLE` or `VOLATILE`. 
### routing_api_srid()

Same pattern as `routing_graph_srid()`.
Returns `4326` (WGS 84) — web-facing SRID, used for all API inputs and outputs.
### routing_topology_tolerance_m()
**Intention**
Centralises the topology tolerance chosen (in meters) at the graph's creation. 
The pgRouting `pgr_CreateTopology()` function needs this value. 
Makes the topology tolerance chosen transparent for the engine and stored in one place only. 

**Signature**
```SQL
routing_topology_tolerance_m() -> double precision 
```
**Returns**
`1.0` — one meter tolerance. Lambert-93 (EPSG:2154) is meter-based,
so this value maps directly to a real-world distance.
Would be meaningless with a degree-based SRID such as 4326.

**Preconditions**
None.

**Edge cases**, **Errors**, **Dependencies**, **Why `IMMUTABLE`?** See `routing_graph_srid()`.

### routing_default_speed_kmh()
**Intention**
Centralises the default cycling speed used for travel time estimation.
Called by `route_metrics_nodes()` and `route_metrics_snap()` as a default
parameter value — avoids hardcoding in post-processing functions.

**Signature**
```SQL
routing_default_speed_kmh() -> double precision 
```
**Returns**
`15.0` — estimated average cycling speed in km/h.
Reasonable default for urban cycling; can be overridden at call time.

**Preconditions**
None.

**Edge cases**, **Errors**, **Dependencies**, **Why `IMMUTABLE`?** See `routing_graph_srid()`.

## Pre-processing
### snap_to_nearest_node(lon, lat)
**Intention**

Bridge between user-facing coordinates (EPSG:4326) and the routing graph 
(EPSG:2154). Returns the nearest graph vertex id so routing functions can 
work from real-world geographic inputs.

**Signature**
```SQL
snap_to_nearest_node(lat double precision, lon double precision) → BIGINT̀
``` 

**Returns**
`BIGINT` - id of the nearest graph vertex to the input coordinates
note : entry coordinates respect human lat/lon logic. The function reverts inputs when using postgis.

**Preconditions**
Graph state is validated internally via `assert_graph_ready()`.
No external precondition required from the caller.

**Edge cases**
If input coordinates fall outside the graph's bounding box, the function 
returns the nearest boundary vertex without error. Routing may produce 
unexpected results in that case.

**Errors**
None raised by this function directly. See `assert_graph_ready()` for 
graph state errors.

**Dependencies**
`assert_graph_ready()`, `routing_vertices`, `routing_api_srid()`, `routing_graph_srid()`

## Core routing
### dijkstra_only(start_node, end_node)
**Intention**
core routing function. Returns minimum values necessary to build a route in order to be wrapped in different functions and used in different cases (i.e. multi-stops routes). Uses pgr_bdDijkstra for better optimisation.

**Signature**
```SQL
dijkstra_only(start_node BIGINT, end_node BIGINT)
```

**Returns**
| Column   | Type             | Unit | Description                        |
|----------|------------------|------|------------------------------------|
| seq      | INTEGER          | —    | Step order along the route         |
| edge_id  | BIGINT           | —    | Edge id in `routing_edges`         |
| cost     | DOUBLE PRECISION | —    | pgRouting internal cost value      |
| geom     | geometry(LineString) | — | Edge geometry in EPSG:2154         |
| length_m | DOUBLE PRECISION | m    | Edge length in meters              |

**Preconditions**
Core function. Needs a valid graph but doesn't have guardrails to check graph's state. 

**Edge cases**
None handled here — upstream snapping will handle boundary (WIP) and downstream metrics handles path validation.

**Errors**
None raised by this function directly.

**Dependencies**
`routing_graph_srid`, `routing_edges`

### dijkstra_snap(lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION, lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION)
**Intention**
wrapper for the core routing function: returns route from point A to point B with snapping. Output minimal. 

**Signature**
```SQL
dijkstra_snap(lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION, lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION)
```
**Returns**
same table as `dijkstra_only()` (see above)

**Preconditions**
"Preconditions are inherited from dependencies — see `snap_to_nearest_node()`."

**Errors**
If the query returns an empty table, then this function raises an exception: 
```SQL
      '[ROUTING:NO_PATH] no path found between selected points'
      USING ERRCODE = 'P0001';
```

**Dependencies**
`snap_to_nearest_nodes`, `dijkstra_only`

## Post-processing
### route_metrics()

**Intention**
Post-processing of the routing result : transforms raw data into metrics understandable by the user (distance, estimated time)
**Signature**

```SQL
route_metrics(
      lat1 DOUBLE PRECISION, 
      lon1 DOUBLE PRECISION, 
      lat2 DOUBLE PRECISION, 
      lon2 DOUBLE PRECISION,
      speed_kmh DOUBLE PRECISION DEFAULT routing_default_speed_kmh()
)
```

**Returns**

| Column   | Type             | Unit | Description                        |
|----------|------------------|------|------------------------------------|
| total_m      | DOUBLE PRECISION         | m   | routes total length in meters         |
| total_km  | DOUBLE PRECISION           | km    | route total length in kilometers        |
| estimated_time_min     | DOUBLE PRECISION | time    | estimated time of the total route      |
| route_geom_graph   | geometry(LineString) | — | route in Linestring in EPSG:2154         |
| route_geom_api | geometry(LineString) | —  | route in Linestring in EPSG:4326              |


**Preconditions**
Needs a valid route from `dijkstra_snap()`. Will raise error if not.

**Edge cases**

If speed/kmh <= 0 or NULL estimated_time_min returns NULL.

**Errors**

check the edges count from `dijkstra_snap()`. If count is 0 then raises the following exception:
```SQL
      '[ROUTING:NO_PATH] no path found between selected points'
      USING ERRCODE = 'P0001';
```
> This should never be triggered in V1 : one graph, one component, clean data => impossible for dijkstra to get lost. Preventive implementation for future versions of this engine.


**Dependencies**

`dijkstra_snap()`, `routing_graph_srid()`, `routing_api_srid()`

## Export
### export_route_api(...)

**Intention**
exports as Geojson from two sets of lat/lon coordinates the Linestring + metrics created in `route_metrics()`, function destinated to be consumed by the API.

**Signature**
```SQL
export_route_api(
      lat1 DOUBLE PRECISION,
      lon1 DOUBLE PRECISION, 
      lat2 DOUBLE PRECISION,
      lon2 DOUBLE PRECISION, 
      speed_kmh DOUBLE PRECISION DEFAULT 15.0
)
```
**Returns**

| Field   | Type             | Description                        |
|----------|------------------|------------------------------------|
| geometry      | Linestring(EPSG:4326)         | route      |
| properties.distance_km  | float,km          | total route length        |
| properties.estimated_time_min    | float,min | estimated time of the total route      |
| properties.speed_kmh   | float,km/h | time calculation used speed        |


**Preconditions**
Preconditions are inherited from dependencies — see route_metrics().

**Edge cases and Errors**
no handling of errors or edge cases in this function.

**dependencies**

`route_metrics()`

## Guardrails


### assert_graph_preconditions_on(p_table_name) / assert_graph_preconditions()

**Intention**
Validates minimum viable data state before graph creation. Raises exceptions if anything is missing. `assert_graph_preconditions_on()` is the testable generic version ; `assert_graph_preconditions()` is the production wrapper hardcoded on `public.routes_v1`.

**Signatures**
```sql
assert_graph_preconditions_on(p_table_name TEXT) → void
assert_graph_preconditions() → void
```

**Checks performed (in order)**
1. Table exists
2. Required columns : `geom`, `fid`, `cost`, `reverse_cost`
3. SRID matches `routing_graph_srid()` (EPSG:2154)
4. `length_m` has no NULL values (if column exists)

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

### assert_graph_ready()

**Intention**
Post-build guardrail. Validates that the routing graph artifacts exist and are usable before any routing query. Currently called at every queue. **WIP** : to be moved to build-time only and refactored into a testable generic version following the same model as `assert_graph_preconditions_on()`.

**Signature**
```sql
assert_graph_ready() → void
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

