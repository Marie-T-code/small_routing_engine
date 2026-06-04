# TO DO

## THIS MONTH (JUNE) — finish the dev prototype, then CLOSE

### Tests
- [ ] Pytest: wrap `assert_graph_preconditions_on` + `assert_graph_ready_on`
- [ ] Pytest POIs (`test_pois.py`) — finalize (fix unhandled `ValueError` on `POICategory("zombie")` -> 400 instead of 500, fix already spotted in the blueprint)
- [ ] Pytest SQL guardrails (`test_guardrails.py`) — to create
- [ ] Testcontainers: isolated test runs
- [ ] Remove hardcoded `5433` in `conftest.py` (logical prerequisite for the testcontainers setup)
- [ ] GitHub Actions: CI on the pytest suite

### Frontend
- [ ] Minimal Leaflet frontend (demonstrable dev state)

### Conditional — IF tests + CI + frontend done before the 21st
- [ ] Minimal raster service

### Known bugs 
- [ ] **[oneway true/1]** `03_costs_config.sql`: the `reverse_cost` CASE only tests `oneway = 'yes'`; OSM values `true` and `1` fall into the ELSE -> `reverse_cost = length_m` -> one-way edges traversable against direction (silent: no error, wrong route). Confirmed in Nevers data (`GROUP BY oneway` shows both `yes` and `true`). Fix: normalize `oneway` at import, or `WHEN oneway IN ('yes','true','1') THEN -1`. Note: the `oneway = -1` (reverse) side is correct; only the `yes` family is affected.
- [ ] **[#7 geometry]** Duplicate consecutive points in the route LineString. Likely edge orientation in `route_metrics`.
- [ ] **[#10 same_point]** `start = end` -> misleading 404 `ROUTING:NO_PATH`. Zero-edge path read as "no path". Detect `s_id = t_id` in `dijkstra_snap`, return a trivial 0m route or `ROUTING:SAME_POINT` (400).
- [ ] **[500 coverage]** Map error code + message for the 500 = no `graph_coverage`. `ST_Within` on 0 rows = NULL, not false.
- [ ] **[COVERAGE_OUT_OF_BOUNDS]** Add in the pois repo. Currently returns 404 out-of-zone instead of 422, no coverage check.
- [ ] **[db_errors]** Check and harden `utils/db_errors.py`. High risk it breaks on 0 square brackets.

## WHEN TIME (not urgent)

### API cleanups
- [ ] Frenglish: "test_db is a success!" -> proper English message
- [ ] POI sub-categories
- [ ] Audit all debug functions + add a "debug" category in `engine_functions.md`

### SQL refactoring
- [ ] DROP IF EXISTS -> CREATE OR REPLACE once signatures are stable
- [ ] Renumber SQL files (03_injection -> docker loader, renumber 01_config, 02_graph...)
- [ ] QOL: vertices view `the_geom` -> `geom`
- [ ] `graph_coverage_bbox` plpgsql function (for consistency)
- [ ] pgRouting 3.8 migration: `pgr_createTopology` + `pgr_analyzeGraph` deprecated (work with warning)
- [ ] Really not urgent: can `pgr_createTopology()` generate different source/target IDs on a rebuild? (can a node ID in the vertices table differ from the edge's one?)

## ROADMAP (validated)
1. ~~**MAY**: BBoxes + architecture decision~~ (done)
2. ~~**MAY**: Curl test suite~~ (done)
3. **JUNE**: finish the dev prototype -> pytest + testcontainers + GitHub Actions + frontend, then CLOSE (+ raster service if done before the 21st)
4. **NEXT**: fork into a production project
5. **NEXT**: typing -> Pydantic v2 -> FastAPI migration
6. **NEXT**: performance -> async -> connection pooling
7. **NEXT**: AWS deployment
