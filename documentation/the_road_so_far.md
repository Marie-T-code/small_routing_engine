# The Road So Far

Chronological log of the `small_routing_engine` project, grouped by month.
Each entry is derived from a Git commit message.


> Note : as the project became public at the end of March, this is when regular commits replaced one big monthly commit.

---

## 2026-01 — Bootstrap & first separation of concerns

- Initial commit.
- First refactorisation: separating functions by role.

## 2026-02 — Engine guardrails, Docker orchestration & stable baseline

- Engine guardrails: *fail fast* if a problem is detected, run silently otherwise.
- Docker: validated pipeline orchestration with stub services.
- Baseline reached: masters + graph + routing SQL OK (logging + pipeline stable).

## 2026-03 — Routing engine milestone

- Routing engine milestone: guardrails, pipeline, Flask API and documentation.
- Readme adjustments.

## 2026-04 — OOP architecture, structured errors & documentation sprint

- Routing engine architecture changes and OOP service creation.
- Finished the `pois` OOP Python service.
- Transformed the API routes blueprint into an OOP routing service.
- Refactor: moved views and guardrails to `04_graph`, added structured SQL error handling.
- `assert_graph_ready` made production-ready (`assert_graph_ready_on.sql`):
  guardrails moved into the graph folder, `MASTER_GRAPH` updated, guardrail now
  called at graph **build** time, `snap_to_nearest_node` modified so the guardrail
  is no longer called at query time.
- Docs: rewrote readme, added `data_model.md` and `architecture.md`, refreshed `docker.md`.
- Fixed the bug where Docker containers pointed to a dead network.
- Docs: refreshed `graph_build`, `pipeline`, and `data_quality`.

## 2026-05 — Bbox optimization, coverage validation & test suites

- Finished April documentation: added a `readme.md` in the documentation folder for clarity;
  finished and tested the `assert_graph` functions (wrapper, core, test).
- Routing: added adaptive bbox optimization with fallback.
- Graph coverage validation + route bbox.
- Fix: refactored the Dijkstra core + fixed GeoJSON export for QGIS display.
- Tests: added curl test suite and a `make test-api` target (17/17).
- Tests: set up the pytest environment and first route test (missing params → 400).
- Fix: parse `ST_AsGeoJSON` result as a dict in the `get_coverage` repository;
  added integration tests for `/api/route` and `/api/coverage`.

---

*Generated from Git commit history. Update monthly.*

Carry on my wayward son...
