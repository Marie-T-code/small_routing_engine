# Error codes — SRE reference

This document catalogues every structured error the engine can raise,
where it originates, and how it surfaces (build failure or HTTP status).

## How error tags work

SQL-side errors are raised with `RAISE ... USING ERRCODE = 'P0001'` and
carry a **structured tag** in square brackets at the start of the
message, e.g.:

```
[ROUTING:NO_PATH] no path found between selected points
```

`P0001` is PostgreSQL's generic "raise_exception" SQLSTATE — every
deliberate `RAISE` in this engine uses it, so the **tag**, not the
SQLSTATE, is what identifies the error. The Python layer parses it:

- `parse_pg_error_code()` extracts the text between `[` and `]`
  (e.g. `ROUTING:NO_PATH`) and the repository maps it to a domain
  exception.
- `parse_pg_error_message()` extracts the human-readable text after the
  `]` and passes it to the HTTP response.

Because the whole mechanism keys on the bracketed tag, the tags below
must match the source exactly — a renamed prefix silently breaks the
mapping.

A second class of errors is raised **in Python only** (input validation,
before any SQL runs). These carry no tag and no `P0001` — they are listed
in their own section at the end.

---

## 1. Build-time errors — graph preconditions

Raised by `assert_graph_preconditions()` **before** topology creation,
during the master build. These never reach an HTTP client: they fail the
`builder` container (via `psql -v ON_ERROR_STOP=1`) and abort the build.
The "HTTP" column shows what the generic handler *would* return if the
error somehow reached runtime (`except Exception` → 500), but in normal
operation that path is never taken — guardrails do not run at request
time (see [`architecture.md`](./architecture.md), *Why guardrails run at
build time only*).

| # | SQLSTATE | tag | message | context | HTTP if runtime |
|:-:|----------|-----|---------|---------|----------------:|
| 1 | P0001 | `GRAPH:TABLE_MISSING` | public.routes_v1 does not exist (run import step) | build | 500 |
| 2 | P0001 | `GRAPH:COL_GEOM_MISSING` | public.routes_v1.geom is missing | build | 500 |
| 3 | P0001 | `GRAPH:COL_FID_MISSING` | public.routes_v1.fid is missing (required by pgr_createTopology) | build | 500 |
| 4 | P0001 | `GRAPH:COST_COLS_MISSING` | cost/reverse_cost columns are missing (run 03_costs_config.sql) | build | 500 |
| 5 | P0001 | `GRAPH:GEOM_ALL_NULL` | routes_v1.geom contains no non-NULL geometries | build | 500 |
| 6 | P0001 | `GRAPH:SRID_MISMATCH` | routes_v1.geom SRID is %, expected %. | build | 500 |
| 7 | P0001 | `GRAPH:LENGTH_M_NULLS` | routes_v1.length_m contains NULL values (run 02_add_length_m.sql) | build | 500 |

---

## 2. Build-time errors — graph state

Raised by `assert_graph_ready()` **after** the graph is built, as the
final verification step of the build. Same context as section 1: these
fail the build, not an HTTP request. Several tags appear twice because the
guardrail validates both the `routing_edges` and `routing_vertices` views.

| # | SQLSTATE | tag | message | context | HTTP if runtime |
|:-:|----------|-----|---------|---------|----------------:|
| 8 | P0001 | `GRAPH_STATE:VIEWS_MISSING` | routing_edges view missing (run MASTER_GRAPH) | build | 500 |
| 9 | P0001 | `GRAPH_STATE:VIEWS_MISSING` | routing_vertices view missing (run MASTER_GRAPH) | build | 500 |
| 10 | P0001 | `GRAPH_STATE:CRITICAL_COLS_MISSING` | routing_edges missing critical columns (source/target/cost/reverse_cost/geom). | build | 500 |
| 11 | P0001 | `GRAPH_STATE:CRITICAL_COLS_MISSING` | routing_vertices missing id column. | build | 500 |
| 12 | P0001 | `GRAPH_STATE:CRITICAL_COLS_MISSING` | routing_vertices missing the_geom column. | build | 500 |
| 13 | P0001 | `GRAPH_STATE:EMPTY` | routing_edges is empty (run MASTER_GRAPH). | build | 500 |
| 14 | P0001 | `GRAPH_STATE:EMPTY` | routing_vertices is empty (run MASTER_GRAPH). | build | 500 |
| 15 | P0001 | `GRAPH_STATE:TOPOLOGY_NULL` | routing_edges has NULL source/target (topology not built). | build | 500 |
| 16 | P0001 | `GRAPH_STATE:COST_NULL` | routing_edges has NULL cost/reverse_cost (run costs configuration step). | build | 500 |
| 17 | P0001 | `GRAPH_STATE:GEOM_ALL_NULL` | routing_edges has no non-NULL geometries. | build | 500 |
| 18 | P0001 | `GRAPH_STATE:SRID_MISMATCH` | routing_edges.geom SRID is %, expected %. | build | 500 |

> The `assert_graph_ready_on()` test suite exercises 13 cases (one per
> code above, with `GEOM_ALL_NULL` and `SRID_MISMATCH` also tested on the
> vertices view, plus a success case). See
> [`engine_functions.md`](./engine_functions.md).

---

## 3. Runtime errors — routing & coverage

Raised by the routing functions during an actual API request. These do
surface as HTTP responses. The same SQL tag can be mapped by more than
one service into its own domain exception, but the resulting HTTP status
is consistent.

| # | SQLSTATE | tag | message | raised by | mapped to (Python) | HTTP |
|:-:|----------|-----|---------|-----------|--------------------|-----:|
| 19 | P0001 | `ROUTING:NO_PATH` | no path found between selected points | `dijkstra_snap` / `route_metrics` | `RouteNotFoundError` (`/api/route`) | 404 |
| 20 | P0001 | `ROUTING:NO_PATH` | no path found between selected points | `route_metrics` (via POI search) | `POIRouteNotFoundError` (`/api/pois_search`) | 404 |
| 21 | P0001 | `COVERAGE:OUT_OF_BOUNDS` | Point (%, %) is outside graph coverage area. | `is_within_coverage` | `PointOutOfCoverageError` (`/api/route` and `/api/pois_search`) | 422 |

> **Note on `ROUTING:NO_PATH` (rows 19–20).** Raised in two places
> (`dijkstra_snap` after its full-graph fallback fails, and `route_metrics`
> on a zero-edge result), mapped by two consumers (`RouteNotFoundError`
> for routes, `POIRouteNotFoundError` for POI search), both 404. On the
> current single-component graph this is not expected to fire and is not
> covered by a test — it is kept as a defensive guard.

> **Note on coverage (row 21).** `is_within_coverage` is called by **both**
> repositories as a fail-fast pre-engine check; an out-of-area request
> (route or POI) surfaces as 422 before any routing runs. The shared
> `PointOutOfCoverageError` lives in `utils/exceptions.py`.

---

## 4. Application-level errors (Python validation)

Raised in the Flask layer **before** any SQL runs — input validation in
the DTO `validate()`, or inline in the blueprint for checks that can run
before the DB connection opens. They carry no SQL tag and no `P0001`;
they are pure Python exceptions (or inline checks) mapped directly to a
status code.

| # | source | condition | HTTP | endpoint |
|:-:|--------|-----------|-----:|----------|
| 22 | inline check | missing required query parameter(s) | 400 | both |
| 23 | `InvalidCoordinatesError` | malformed / out-of-range coordinates | 400 | `/api/route` |
| 24 | `InvalidSpeedError` | non-positive or invalid speed | 400 | `/api/route` |
| 25 | `InvalidCategoryError` | category not in `bike, culture, services, catering` | 400 | `/api/pois_search` |
| 26 | `InvalidRadiusError` | invalid search radius | 400 | `/api/pois_search` |
| 27 | `SamePointError` | start and end points are identical | 400 | both |

> **Category validation (row 25).** The blueprint constructs
> `POICategory(category)`, which raises a plain `ValueError` if the string
> is not a member; the blueprint catches it and re-raises
> `InvalidCategoryError` with the list of accepted values. The domain
> exception, not the raw `ValueError`, is what the handler maps to 400.

> **Same-point check (row 27).** Raised by each service's DTO `validate()`
> when start and end coordinates are strictly equal — a fail-fast reject
> before the engine runs. The shared `SamePointError` lives in
> `utils/exceptions.py`. It does not detect *near-identical* points that
> snap to the same graph node; that case is a separate backlog item.

---

## Quick reference — HTTP status summary

| Status | Meaning in this API |
|-------:|---------------------|
| 200 | Success |
| 400 | Malformed or rejected request before the engine runs: missing params, bad coordinates, invalid speed, invalid radius, unknown category, or identical start/end points (`SamePointError`) |
| 404 | No route found between two distinct in-coverage points (`ROUTING:NO_PATH`) — defensive, not expected to fire on the current single-component graph |
| 422 | A point is outside the graph coverage area (`COVERAGE:OUT_OF_BOUNDS`), on both `/api/route` and `/api/pois_search` |
| 500 | Unexpected error (uncaught exception; also where a build-time guardrail would land if it ever ran at request time — which it does not) |

---

## Cross-references

- [`architecture.md`](./architecture.md) — guardrail placement, build-time
  vs runtime philosophy, the Python layer's exception ordering
- [`engine_functions.md`](./engine_functions.md) — which function raises
  which tag, and the guardrail test suites
- [`data_model.md`](./data_model.md) — the `graph_coverage` table behind
  `COVERAGE:OUT_OF_BOUNDS`
