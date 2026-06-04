# Pipeline

End-to-end documentation of how data flows through the project, from
OpenStreetMap sources to the API responses.

This file focuses on **what happens, in what order, with which tools**.
For the structure of the SQL code that handles the in-database stages,
see [`architecture.md`](./architecture.md). For the rationale behind
data quality choices and observed limits, see
[`data_quality.md`](./data_quality.md).

---

## 1. Overview

The project has two preparation pipelines (one per dataset), a shared
ingestion stage, and two runtime services:

```text
ROUTES                           POIs
  │                                │
  Overpass Turbo                   Geofabrik regional PBFs (×2)
  (Nevers + 15 km)                 │
  │                                osmium extract (bbox)  ×2
  │                                │
  │                                osmium merge
  │                                │
  │                                Temporary PostGIS DB
  │                                (import all layers)
  │                                │
  QGIS                             QGIS
  (snap, components, attributes)   (filter on amenity tag)
  │                                │
  nevers_clean.gpkg                nevers_clean_points.gpkg
       │                                  │
       └──────────────┬───────────────────┘
                      ▼
              ogr2ogr → PostGIS
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
  Routing engine             POI service
  (PL/pgSQL, nested          (Python OOP,
   functions, Dijkstra)      ST_DWithin around route)
        │                           │
        └─────────────┬─────────────┘
                      ▼
                 Flask API
                 (GeoJSON)
```

---

## 2. Design principles

Two principles drive the pipeline design. Both are intentional choices,
documented here because they explain decisions that recur throughout
the project.

### 2.1 Two preparation pipelines, one ingestion contract

The routes and POIs datasets have different acquisition needs (different
tools, different geographic scopes, different filtering logic). Forcing
both through a single pipeline would either overload the simpler one or
underserve the more complex one.

Instead, both pipelines converge on a **shared format pivot**: a clean
GeoPackage in EPSG:2154. From that point onward, the ingestion logic is
identical — `ogr2ogr` imports the GeoPackage into PostGIS, and downstream
SQL or Python services don't need to know how the data was prepared.

This decoupling means the project can later add new data sources
(elevation rasters, transit networks, local lighting data) by writing a
new preparation pipeline that produces a compatible GeoPackage. The
ingestion stage doesn't change.

### 2.2 Different runtime philosophies per domain

The two domains (routing, POI search) have very different complexity,
and the project applies the right tool at the right level for each:

- **Routing**: dense business logic (Dijkstra orchestration, snapping,
  metrics, GeoJSON export, build-time guardrails) → implemented in
  PL/pgSQL with **nested functions**, where the data lives. Python only
  orchestrates the call and exposes the result.
- **POI search**: simple business logic (find POIs near a computed
  route → one `ST_DWithin` query) → implemented in **Python OOP**,
  because there is no benefit to wrapping a single spatial query in
  PL/pgSQL.

This avoids two failure modes common in single-developer projects:
putting application logic in SQL (where it becomes untestable), or
putting performance-critical data work in Python (where it forces large
fetches over the network).

---

## 3. Routes pipeline (preparation)

### 3.1 Source extraction with Overpass Turbo

The routes dataset is extracted via **Overpass Turbo** with a query
targeting Nevers + a 15 km radius. Overpass Turbo automatically:

- merges data across administrative boundaries (Nevers sits at the edge
  of two regions, Bourgogne-Franche-Comté and Centre-Val de Loire)
- snaps geometries at region borders
- exports a GeoJSON file ready for QGIS

This extraction worked but reached the limits of older hardware —
Overpass Turbo's GeoJSON output for Nevers + 15 km nearly killed a
5-year-old laptop and struggled to load into QGIS due to the file size.
This experience drove the choice to use `osmium-tool` for the POI
pipeline, where larger volumes were expected.

### 3.2 QGIS preparation

Inside QGIS, the routes dataset goes through:

- **Reprojection** to EPSG:2154 (Lambert-93)
- **Linestring explosion** (multilinestrings split into individual
  linestrings, one per edge)
- **Snapping** at 1-meter tolerance (joins disconnected segments that
  should be continuous)
- **Connectivity analysis** with GRASS (`v.net.components`) — labels
  every edge with a connected-component id
- **Main component selection** — keep only the largest component
  (~76,000 edges)
- **Attribute table cleaning** — keep only the columns relevant for
  routing (`osm_id`, `highway`, `name`, `oneway`, `bicycle`,
  `cycleway`, `surface`, `lit`, `maxspeed`, `comp`); drop everything
  else

Each of these steps is detailed in
[`data_quality.md`](./data_quality.md), including the rationale for
keeping or dropping specific columns.

### 3.3 Export to GeoPackage

The cleaned single-component layer is exported as
`nevers_clean.gpkg`, in EPSG:2154. From this point onward, the file
is treated as immutable input for the ingestion stage.

---

## 4. POIs pipeline (preparation)

### 4.1 Source extraction with osmium-tool

The POI dataset is extracted from two **Geofabrik PBFs** (Bourgogne and
Centre-Val de Loire), because Nevers sits between the two regions.
The extraction uses three osmium-tool sub-commands. Paths below assume
the project root as the working directory.

**Step 1 — Clip each regional PBF to the Nevers bounding box.**

```bash
osmium extract --bbox 2.95,46.85,3.36,47.13 \
  ./DATA/raw/points/bourgogne.osm.pbf \
  -o ./DATA/raw/points/nevers_bourgogne.osm.pbf

osmium extract --bbox 2.95,46.85,3.36,47.13 \
  ./DATA/raw/points/centre-260330.osm.pbf \
  -o ./DATA/raw/points/nevers_centre.osm.pbf
```

(Note: each `osmium extract` command must be on a single line in the
shell — the line continuations above are for readability only.)

**Step 2 — Verify both clipped files contain data.**

```bash
osmium fileinfo ./DATA/raw/points/nevers_bourgogne.osm.pbf
osmium fileinfo ./DATA/raw/points/nevers_centre.osm.pbf
```

This intermediate check catches a bbox typo or a corrupt source PBF
before the merge step. If either file reports zero nodes/ways, the
bbox or the source needs to be re-checked.

**Step 3 — Merge the two clipped PBFs into one.**

```bash
osmium merge \
  ./DATA/raw/points/nevers_bourgogne.osm.pbf \
  ./DATA/raw/points/nevers_centre.osm.pbf \
  -o ./DATA/raw/points/nevers_zone.osm.pbf
```

**No tag filtering at the osmium stage.** The clipped+merged PBF
contains *every* OSM layer (roads, paths, points, polygons, amenities,
boundaries, etc.). This is intentional: filtering is deferred to QGIS,
where data can be **visualised before being filtered**.

The reasoning is methodological: a tag-filter applied blindly at the
extraction stage assumes that the filter is correct, which is only
verifiable by looking at the data afterwards. Importing everything
into a temporary store and exploring it visually catches edge cases
(unexpected tag values, layers worth knowing about) that a blind
filter would miss.

### 4.2 Temporary PostGIS database

The merged PBF is loaded into a **temporary PostGIS database** named
`osm_explore` using `osm2pgsql`:

```bash
PGPASSWORD=$PGPASSWORD osm2pgsql \
  -d osm_explore \
  -U $PGUSER \
  -H $PGHOST \
  -P $PGPORT \
  ./DATA/raw/points/nevers_zone.osm.pbf
```

This database is not the project's main database — it exists only as
a staging area for visual exploration in QGIS. Once the relevant layer
has been identified and filtered, the temporary database is dropped.

This step lags slightly even on recent hardware (four layers across
two regions), but remains tractable — well below the limits hit by
Overpass Turbo on the routes side.

### 4.3 QGIS filtering

Inside QGIS, the relevant POI layer is identified and filtered:

- **Layer selection**: keep only the points layer (drop ways and
  polygons; both have their own use cases but are not in scope here)
- **Amenity filter**: keep only points with a non-empty `amenity` tag.
  Points without an amenity carry no semantic information for the user
  and are dropped rather than kept as low-quality data.
- **Categorisation**: each amenity is mapped to one of four functional
  categories (`velo`, `ravitaillement`, `services`, `culture`). The
  category mapping is stored in the GeoPackage itself, not in the
  database — meaning the database receives already-categorised data.

For the rationale behind the strict amenity filter (and why this
trade-off is the opposite of the routes pipeline), see
[`data_quality.md`](./data_quality.md).

### 4.4 Export to GeoPackage

The filtered POIs layer is exported as `nevers_clean_points.gpkg`,
in EPSG:2154. The temporary `osm_explore` database is then dropped.

---

## 5. Common ingestion

### 5.1 ogr2ogr import to PostGIS

Once both GeoPackages are ready, each is loaded into its destination
table by an `ogr2ogr` import script (`import_routes.sh`,
`import_pois.sh`), orchestrated by `import_all.sh`:

| GeoPackage                   | Internal layer        | Destination table |
|------------------------------|-----------------------|-------------------|
| `nevers_clean.gpkg`          | `roads_clean_v1`      | `public.routes_v1`|
| `nevers_clean_points.gpkg`   | `nevers_clean_points` | `public.pois`     |

Each script truncates its target table, then appends the layer. The
`TRUNCATE` + `-append` combination is a deliberate choice: it keeps the
import **idempotent** (re-running never duplicates rows) while
`-append -addfields` acts as a safety net — if the GeoPackage gains a
column between iterations, the import absorbs it instead of failing.
This is a prototype-stage convenience; the import will be tightened once
the schema is final.

Differences in acquisition pipeline are fully absorbed by the GeoPackage
format pivot (see section 2.1): the same script pattern handles both
files, only the layer name, geometry type, and destination differ.

The full commands (connection string, `ogr2ogr` flags, env-var
conventions) and how this stage runs inside Docker are documented in
[`docker.md`](./docker.md). This stage is automated by the **loader**
service.

### 5.2 SQL build pipeline

After the loader exits successfully, the **builder** service runs the
master SQL scripts in order:

1. `00_MASTER_CONFIG.sql` — load configuration functions
2. `10_MASTER_GRAPH.sql` — preprocessing, graph creation, views,
   guardrails
3. `20_MASTER_ROUTING_FUNCTIONS.sql` — define runtime functions

Among other things, the preprocessing phase computes `length_m` for
each edge using PostGIS spatial functions — this calculation is done
at build time in SQL, not during the QGIS preparation. The full
breakdown of each master and the sequence of SQL files they invoke is
documented in [`architecture.md`](./architecture.md) section 3.

---

## 6. Runtime

The Python API follows a layered OOP pattern: Blueprint, DTO, Service,
Repository, with explicit responsibilities at each level. The Blueprint
constructs the input DTO from the HTTP request; the DTO carries
validation logic; the Service orchestrates the call to the Repository;
the Repository runs the SQL and returns a Model.

### 6.1 Routes — SQL-driven routing engine

A request to `GET /api/route` flows through:

```text
HTTP request
    → Blueprint (parses query params)
    → DTO RouteSearchRequest (validates input)
    → Service (orchestrates)
    → Repository (DB call)
    → PL/pgSQL: export_route_api()
        → route_metrics()
            → dijkstra_snap()
                → snap_to_nearest_node()
                → dijkstra_only() [pgr_dijkstra, directed]
```

The full function dependency chain is documented in
[`architecture.md`](./architecture.md) section 4.

### 6.2 POIs — Python service with ST_DWithin

The POI search runs as a Python OOP service over a single spatial query.
A request to `GET /api/pois_search` flows through:

```text
HTTP request
    → Blueprint (parses query params)
    → DTO (validates input)
    → Service (orchestrates)
    → Repository: find_pois_along_route()
    → SQL: SELECT ... FROM pois
           CROSS JOIN route_metrics(...) AS r
           WHERE ST_DWithin(pois.geom, r.route_geom_graph, radius_m)
             AND category = <category>
           ORDER BY distance
```

The search is **route-relative**, not a full-collection dump: it computes
a route via `route_metrics()`, then keeps the POIs within `radius_m` of
that route, filtered by a mandatory category, ordered by distance.

Two consequences flow from this design:

- **It depends on routing.** Because the query calls `route_metrics()`,
  the POI search inherits routing failures — notably `[ROUTING:NO_PATH]`,
  which the repository re-maps to a POI-specific exception
  (`POIRouteNotFoundError`).
- **It does not yet check coverage.** Unlike the route service, the POI
  path does not call `is_within_coverage()`. An out-of-area POI search
  therefore surfaces as a routing error rather than a clean coverage
  error — a known gap to align during the POI test pass.

The data-layer view of this query (which index serves it, why category
is a real predicate) is in [`data_model.md`](./data_model.md) section 2.2.

---

## 7. Cross-references

- [`architecture.md`](./architecture.md) — SQL file structure, master
  orchestration, function dependency chain
- [`data_model.md`](./data_model.md) — tables, views, indexes, SRID
  strategy, configuration functions
- [`data_quality.md`](./data_quality.md) — preprocessing rationale,
  observed limits, recommendations
- [`graph_build.md`](./graph_build.md) — how `pgr_createTopology()`
  builds the routable graph
- [`docker.md`](./docker.md) — service orchestration that runs the
  loader and builder
- [`engine_functions.md`](./engine_functions.md) — full PL/pgSQL
  function reference