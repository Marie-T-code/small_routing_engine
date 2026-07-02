# TO DO

## THIS MONTH (JUNE) — finish the dev prototype, then CLOSE

### Tests
- [x] Pytest: wrap `assert_graph_preconditions_on` + `assert_graph_ready_on` **(already ...) DONE**
- [x] Pytest SQL guardrails (`test_guardrails.py`) — to create **DONE**
- [x] Testcontainers: isolated test runs **DONE**
- [X] Remove hardcoded `5433` in `conftest.py` (logical prerequisite for the testcontainers setup) **DONE**
- [x] GitHub Actions: CI on the pytest suite
- [x] finish `test_routes.py` **DONE**
### Frontend
- [x] Minimal Leaflet frontend (demonstrable dev state : route + pois along said route) **DONE**

### Conditional — IF tests + CI + frontend done before the 21st UPDATE : moved to first week of July. Cause : long heatwave cause project delay.
- [ ] Minimal raster service

### Known bugs 
- [x] [oneway robustness] reverse_cost CASE hardened to IN ('yes','true','1').Nevers data only contains yes/no/-1/empty (verified via GROUP BY oneway),so no behavior change on this dataset. true/1 are attested OSM synonyms of es (historic, now deprecated but present in older/other extracts) — hardened or portability. 'reverse' is NOT a oneway value (that's 'reversible', out of scope), so cost stays on '-1'. TODO: synthetic test with a oneway='true' edge to assert it becomes non-traversable against direction. **DONE**
- [x] **[#7 geometry]** Duplicate consecutive points in the route LineString. Likely edge orientation in `route_metrics`.
SOLVED
EXPLANATION (tldr : as is forward -> reverse = node duplication. Because simple 2 points linestring. If evolutions => complex nodes linestring then actual *ST_RemoveRepeatedPoints* won't be enough and zigzag might appear in front)
    ST_RemoveRepeatedPoints in route_metrics (line CTE), verified 70->67 then 67=67.
    ROOT CAUSE: route_metrics builds the line with ST_EndPoint per edge, which always
    returns the edge's *target* regardless of traversal direction. At a forward->reverse
    transition, both edges share that target node -> the same point is emitted twice ->
    strict duplicate (dist=0). Measured: 3 dupes = exactly 3 forward->reverse transitions
    on the test route (seq 2->3, 17->18, 63->64). Not ~50% because consecutive reverse
    runs emit distinct nodes; only the forward->reverse switch duplicates.
    NO zigzag because edges are 2-point segments (138 pts / 69 edges).
    CONDITION OF VALIDITY: this fix holds ONLY while edges are 2-point segments.
    If edges become multipoint (curved geometry), reverse-traversed edges would emit
    intermediate points in wrong order -> visible zigzag, which ST_RemoveRepeatedPoints
    does NOT fix. Then switch to the real fix: reorient geom by d.node in dijkstra_only
    (CASE WHEN d.node = r.source THEN r.geom ELSE ST_Reverse(r.geom) END).
- [x] **[#10 same_point]** `start = end` -> misleading 404 `ROUTING:NO_PATH`. Zero-edge path read as "no path". Detect `s_id = t_id` in `dijkstra_snap`, return a trivial 0m route or `ROUTING:SAME_POINT` (400).**DONE**
- [~] **N/A**  **[500 coverage]** Map error code + message for the 500 = no `graph_coverage`. `ST_Within` on 0 rows = NULL, not false.
This error can't show up in the pipeline as is (reconstruction of the table and replacement of any existing table at build). For unmapped errors, addition of `logger.exception` in both poi and route python layers blueprints
- [x] **[COVERAGE_OUT_OF_BOUNDS]** Add in the pois repo. Currently returns 404 out-of-zone instead of 422, no coverage  check. **DONE**
- [X] **[db_errors]** Check and harden `utils/db_errors.py`. 0 brackets was already OK. harmonized twin functions **DONE**

### backlog

- [ ] architecture decision to implement : migrate user input validation from DTO files to blueprint before db connection
- [ ] no mapped error name for missing parameters in the route request in the Flask services. Works as is but for consistency
- [x] add to api dockerfile "apt install curl" missing. 
- [ ] next iteration of the project : once a frontend implemented, review clean and integrate curl test file to test suite. 
- [ ] architecture decision to implement : yml : API service should start after pipeline is executed in production. But implies to think about "dev" profile vs "prod/pipeline" profile. Think about it when time.
- [x] identified ^M presence at the end of some lines therefore => need to strenghten the gitattributes with `* text=auto eol=lf`
- [ ] starting to separate commits by theme. To_DO and the suppression of the_road_so_far.txt to commit in a "documentation" commit at the ~~end of the month~~ the project (around July 15th)


### discovered and fixed this month

- [x] factorized PointOutOfCoverageError in utils/exceptions.py **DONE**
- [x] factorized SamePointError in utils/exceptions.py **DONE**
- [x] conftest → .env.test **DONE**
- [x] first round of documentation update : error_codes_sre.md matches work done up until June 6th. 

### Observability
- [x] [logger.exception] Added logging.getLogger(__name__) + logger.exception
  in the generic `except Exception` handlers of route, POI, and coverage
  blueprints. Unmapped 500s now leave a full server-side traceback in the logs
  while the client still receives a generic error body ("An unexpected error
  occurred"). Rationale: 500s are server-side faults and must be diagnosable;
  4xx (client errors) stay silent. Surfaced during the frontend 500 debug session.

## WHEN TIME (not urgent)

### API cleanups
- [x] Frenglish: "test_db is a success!" -> proper English message => changed 
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

4. **JULY 1st-15th** due to heatwave delay, raster service to implement + doc and then close (all other points validated)
5. **NEXT**: fork into a production project
6.  **NEXT**: typing -> Pydantic v2 -> FastAPI migration
7. **NEXT**: performance -> async -> connection pooling
8. **NEXT**: AWS deployment
