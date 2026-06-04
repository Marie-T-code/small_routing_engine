# How to build a graph using pgRouting

This document explains how `pgr_createTopology()` builds a routable
graph from an edges table — the **general pgRouting mechanics**, agnostic
of this project. For how *this* project orchestrates and hardens that
step (file structure, the vertices-table drop, the loader's role), see
[`architecture.md`](./architecture.md) — section *"Why the vertices table
is dropped before topology creation"*.

> **Deprecation note.** `pgr_createTopology()` is **deprecated since
> pgRouting v3.8.0** (along with `pgr_createVerticesTable`,
> `pgr_analyzeGraph`, and `pgr_analyzeOneway`). It still works — it emits
> a warning and runs — and this project relies on it (and on
> `pgr_analyzeGraph`) on the pgRouting version currently in use. The
> pgRouting project's stated direction is that the user should build the
> topology explicitly instead (e.g. `pgr_extractVertices` plus manual
> `UPDATE`s on `source`/`target`), giving full control over table names
> and permissions. Migrating off the deprecated functions is a roadmap
> item, not a current need. This document describes the function as the
> project uses it today.

## Required edges-table columns

For `pgr_createTopology()` to work, the edges table must contain:

- **id** (or `fid` from QGIS) — unique edge identifier
- **source** — populated by the function
- **target** — populated by the function
- **geom** — edge geometry (LineString)

A **topology tolerance** must also be defined: it controls how
precisely nodes are placed at edge endpoints. In this project, the
tolerance is exposed as a configuration function
(`routing_topology_tolerance_m()`, see
[`data_model.md`](./data_model.md) section 7).

> **Recommendation.** Always work in a precise projected SRID and
> avoid degree-based projections like EPSG:4326 — graph construction
> is sensitive to coordinate precision, and degrees yield imprecise
> topology decisions. (This project builds in EPSG:2154, a meter-based
> projected SRID, so the 1-meter tolerance maps to a real distance.)

---

## How `pgr_createTopology()` works

The function fills the `source` and `target` columns of the edges
(linestring) table. To do so, it:

- creates a new table for nodes, with their id, geometry, and
  topology connectivity flag
- creates indexes on the nodes table automatically
  (`pgr_vertices_<table_name>_pkey` and a spatial index on the
  geometry column) — meaning you don't have to pre-implement those
  in init scripts; you still have to index your edges table though,
  as the function only fills `source` and `target` there
- fills every edge's `source` and `target` with the corresponding
  node IDs

Once this is done, the graph is connected and routing algorithms
(Dijkstra family, A*, isochrones) can run on it.

In this project the call is preceded, in the same transaction, by a
`SELECT assert_graph_preconditions()` — so the topology is never built
on a table that fails the structural checks (missing columns, wrong
SRID, NULL lengths). See
[`engine_functions.md`](./engine_functions.md) for the guardrail's
error codes.

---

## Idempotence pitfall (general mechanics)

Re-running topology creation on an already-built database is where
`pgr_createTopology()` surprises people. Two of its default behaviours
combine into a trap:

- **`rows_where` defaults to "source or target is NULL".** The function
  only processes edges that have not been numbered yet. If `source` and
  `target` are already populated from a previous run, the default
  condition selects nothing and the function returns OK **without doing
  any work**.
- **the vertices table is not cleaned between runs** unless the function
  is called with `clean := TRUE`. A stale (or missing) vertices table can
  therefore survive across rebuilds.

Together, these mean a re-import can leave the graph silently
inconsistent: the function reports success while the vertices table no
longer matches the edges — leading to hard-to-debug routing failures.

**Three ways to force a clean rebuild:**

| Approach | What it does |
|---|---|
| `clean := TRUE` (function parameter) | pgRouting wipes and reassigns `source`/`target`, rebuilding the vertices table |
| `source = NULL, target = NULL` before the call | makes the default `rows_where` reprocess every edge |
| `DROP TABLE <edges>_vertices_pgr CASCADE` before the call | removes the vertices table so it must be rebuilt from current edges |

**What this project does.** It does not nullify `source`/`target` by hand
and does not use `clean := TRUE`. Instead it drops the vertices table
explicitly before the call, and relies on the loader re-importing the
edges fresh (so `source`/`target` always arrive NULL). The reasoning
behind that specific combination — why a `DROP` rather than the `clean`
flag, and how the loader closes the other half of the trap — is the
subject of [`architecture.md`](./architecture.md), section *"Why the
vertices table is dropped before topology creation"*. It is documented
there rather than here because it is a project-design decision, not a
property of pgRouting itself.

---

## Cross-references

- [`architecture.md`](./architecture.md) — how this project orchestrates
  the build and closes the idempotence trap
- [`data_model.md`](./data_model.md) — edges/vertices schemas, the
  configuration functions
- [`engine_functions.md`](./engine_functions.md) — guardrail error codes
  raised around the build
- [`pipeline.md`](./pipeline.md) — the full ETL leading up to graph
  construction
