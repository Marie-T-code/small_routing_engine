# How to build a graph using pgRouting

This document explains how `pgr_createTopology()` builds a routable
graph from an edges table. For the project's specific implementation
of this step (file structure, SQL orchestration), see
[`architecture.md`](./architecture.md).

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
> topology decisions.

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

---

## Idempotence pitfall

`pgr_createTopology()` does **not** regenerate the vertex table if
`source` and `target` are already populated in the edges table. If
you re-import a fresh edges dataset without resetting these columns,
the old vertex table is silently kept and may no longer match the
new edges — leading to hard-to-debug routing failures.

**Quick fix.** Set `source = NULL` and `target = NULL` on the edges
table before calling `pgr_createTopology()`. This forces a clean
rebuild of the vertex table every time.

For the full discussion of this design decision (why it costs
performance, what the long-term cleaner approach would be), see
[`architecture.md`](./architecture.md) section 5.