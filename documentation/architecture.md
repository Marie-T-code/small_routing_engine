# SQL architecture

This document describes the structure of the `SQL/` directory, the
build-time orchestration that turns raw imported data into a routable
graph, and the dependency chain of the routing functions.

It is intended for developers who need to understand the build pipeline
or extend the SQL layer.

For the spatial data structures themselves (tables, views, columns),
see [`data_model.md`](./data_model.md).
For the runtime function reference, see
[`engine_functions.md`](./engine_functions.md).

---

## 1. Overview

The `SQL/` directory is organised as a **numbered, sequential pipeline**.
Each top-level directory corresponds to one stage of the build, and the
numeric prefixes encode the execution order. Three master scripts
orchestrate the pipeline; nothing in the SQL layer is meant to be run
ad hoc.

The build sequence is **safe to re-run** at the master level — functions
use either `CREATE OR REPLACE` (when the signature is stable) or
`DROP IF EXISTS` followed by `CREATE` (when the function signature is
still evolving), and the graph creation step explicitly resets `source`
and `target` columns before invoking `pgr_createTopology` to ensure
consistent vertex generation. Re-running on an already-built database
is safe; full idempotence at the lowest level is tracked for a future
revision (see section 5).

---

## 2. Directory layout

### 2.1 Top-level structure

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

### 2.2 Zoom — `04_graph/`

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
└── 04_guardrails/
    ├── assert_graph_preconditions_on.sql  # Generic precondition function
    ├── assert_graph_preconditions.sql     # Wrapper, uses default args
    ├── assert_graph_ready_on.sql          # Generic post-build function
    └── assert_graph_ready.sql             # Wrapper, uses default args
```

**Why this internal split.** Each subdirectory corresponds to **one
phase** of the graph build:

- `01_pre_processing/` runs on the raw imported table before pgRouting
  touches it.
- `02_graph_creation/` calls `pgr_createTopology` and validates the
  result.
- `03_views/` exposes the canonical interface used by algorithms.
- `04_guardrails/` defines the validation functions used at build time.

This phasing means a developer reading the directory understands the
build sequence without having to read the master script.

### 2.3 Zoom — `05_algorithms/`

```text
05_algorithms/
└── 01_dijkstra/
    ├── 00_pre_processing/
    │   └── snap_to_nearest_node.sql       # API coords → graph vertex
    │
    ├── 01_core/
    │   ├── dijkstra_only.sql              # Raw pgr_bdDijkstra wrapper
    │   └── dijkstra_snap.sql              # Snap + dijkstra
    │
    ├── 02_post_processing/
    │   └── route_metrics.sql              # Distance + time + LineString
    │
    └── 04_export_modes/
        └── export_API_route_feature_api_srid_function.sql  # GeoJSON output
```

**Why `01_dijkstra/` is nested.** The directory leaves room for future
algorithm families: `02_a_star/`, `03_isochrones/`, etc. Each algorithm
family will follow the same internal structure (pre-processing, core,
post-processing, export modes), keeping the architecture predictable as
the project grows.

The numbered subdirectories within `01_dijkstra/` reflect the **runtime
flow** of a single API call: snap → core algorithm → metrics → export.

---

## 3. Build-time orchestration (the masters)

Three master scripts under `06_MASTERS/` define the entry points to the
build pipeline. Masters **only orchestrate** — they contain no business
SQL of their own.

### 3.1 `90_MASTER_ALL.sql` — top-level entry

The script run by the builder service in production. It chains the three
phase masters in order.

```sql
\i /SQL/06_MASTERS/00_MASTER_CONFIG.sql
\i /SQL/06_MASTERS/10_MASTER_GRAPH.sql
\i /SQL/06_MASTERS/20_MASTER_ROUTING_FUNCTIONS.sql
```

The numbering (`00`, `10`, `20`) leaves room for inserting future
masters (e.g. `15_MASTER_POIS.sql`) without renumbering.

### 3.2 `00_MASTER_CONFIG.sql` — runs first

Loads the configuration functions (SRID, topology tolerance, default
speed) before anything else can use them.

```sql
\i /SQL/01_config/routing_constants.sql
```

This master is intentionally minimal: every downstream function depends
on these constants, so they must exist before anything else runs.

### 3.3 `10_MASTER_GRAPH.sql` — preprocessing → graph → views → guardrails

The largest master. It executes the full graph build sequence:

```text
PREPROCESSING
  ├─ Clean table structure (drop ogr2ogr artefacts)
  ├─ Compute length_m for each edge
  ├─ Configure cost and reverse_cost
  └─ Remove invalid / degenerate edges (NULL or < 1m)

GRAPH CREATION
  ├─ Define assert_graph_preconditions_on() and its wrapper
  ├─ Reset source and target columns to NULL
  │  (forces pgr_createTopology to rebuild the vertices table —
  │   see section 5)
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

### 3.4 `20_MASTER_ROUTING_FUNCTIONS.sql` — defines the runtime functions

Loads the functions that the API will eventually call:

```text
PREPROCESSING
  └─ snap_to_nearest_node       (API coords → graph vertex)

CORE
  ├─ dijkstra_only              (wraps pgr_bdDijkstra)
  └─ dijkstra_snap              (snap two endpoints + run dijkstra_only)

POSTPROCESSING
  └─ route_metrics              (distance + time + LineString)

EXPORT
  └─ export_api_route_feature_api  (single GeoJSON Feature, EPSG:4326)
```

> **Note on `export_api_route_feature_api`.** The duplicated `_api`
> suffix is a historical artefact from an early naming iteration. It
> is tracked for renaming in a future schema revision but kept as-is
> in V1 to avoid breaking existing references in masters, tests, and
> the Python repository layer.

This master is the **last** to run. By the time it executes, the graph
is fully built and validated, so the routing functions can be defined
without checking graph state at every call.

---

## 4. Function dependency chain

The runtime call flow, from the entry point that the API calls down to
the lowest-level operation:

```text
                  ┌──────────────────────────────────┐
                  │   API: GET /api/route            │
                  │   (Flask Blueprint → Repository) │
                  └─────────────┬────────────────────┘
                                │
                                ▼
            ┌───────────────────────────────────────┐
            │   export_api_route_feature_api(...)   │
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
   │ node(...)          │   │ wraps pgr_bdDijkstra │
   │ EPSG:4326 → vertex │   │ on routing_edges     │
   └────────────────────┘   └──────────────────────┘
```

Each level has a **single responsibility**:

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

## 5. Why source and target are reset before topology creation

`pgr_createTopology()` is **conditional**: it inspects the `source` and
`target` columns of the edges table, and **skips the vertex table
generation if those columns are already populated**. This makes sense
when a topology has already been correctly built — pgRouting avoids
recomputing what it already has.

However, this conditional behavior is at odds with **the safety of
re-running the build**: if the loader re-imports a fresh edges table
(or the edges have been modified) without rebuilding the vertices
table, the routing functions — specifically `snap_to_nearest_node`,
which queries `routing_vertices` — silently fail because the vertices
no longer match the current edges.

The current solution: the graph creation script **resets `source` and
`target` to NULL before invoking `pgr_createTopology`**, forcing it to
rebuild the vertex table from scratch every time.

This is correct but inefficient — every build recomputes the topology
even when nothing has changed. A more refined check (compare edge
table state, only reset when the edges have effectively changed) is
planned for a future revision but considered out of scope for the
prototype.

This is documented here because it is the kind of subtlety that is not
visible from reading the master script alone, and that would otherwise
resurface as a debugging session for any future maintainer.

---

## 6. Why guardrails run at build time only

Guardrails (`assert_graph_preconditions`, `assert_graph_ready`) are
**only invoked during the master scripts**, never at runtime by the
routing functions. This is a deliberate design choice consistent with
the project's broader build-time precomputation philosophy (see project
readme).

**At build time**, guardrails are essential: they catch a bad import,
a failed topology creation, or a missing index before any user query
can hit a half-broken graph.

**At runtime**, guardrails would add overhead to every API call for
checks that cannot have changed since the build (the graph is static
between builds). Skipping them is safe because the build pipeline
guarantees that the graph reaching the runtime stage is in a known-good
state.

If the graph were ever to change at runtime (live OSM updates,
incremental imports), the guardrail strategy would need to be revisited.
This is not currently planned.

---

## 7. Cross-references

- [`data_model.md`](./data_model.md) — tables, views, indexes, SRID
  strategy, configuration functions
- [`engine_functions.md`](./engine_functions.md) — full PL/pgSQL function
  reference
- [`pipeline.md`](./pipeline.md) — end-to-end ETL from OSM PBF to API
- [`error_codes_sre.md`](./error_codes_sre.md) — structured error tags
  raised by guardrails and routing functions
- [`docker.md`](./docker.md) — service orchestration that runs the
  master scripts
