LAST REVIEWED: NOV 3RD 2026

# TO DO / Keeping track of documentation implementation

## OCTOBER

### Tests
- [x] Pytest: wrap `assert_graph_preconditions_on` + `assert_graph_ready_on` **(already ...) DONE**
- [x] Pytest SQL guardrails (`test_guardrails.py`) — to create **DONE**
- [x] Testcontainers: isolated test runs **DONE**
- [X] Remove hardcoded `5433` in `conftest.py` (logical prerequisite for the testcontainers setup) **DONE**
- [x] GitHub Actions: CI on the pytest suite
- [x] finish `test_routes.py` **DONE**
- [x]Rewrite and rename `_wait_until_graph_ready` => wait until builder exited with code 0.
- [x]Pin testcontainers 4.14.2 in the CI dependencies.
### Frontend
- [x] Minimal Leaflet frontend (demonstrable dev state : route + pois along said route) **DONE**

### Raster addition (multisource cost configuration)
- [ ] Minimal raster service
  - [x] import and clean file
  - [ ] ingest raster data into the pipeline
  - [ ] update cost file 
  - [ ] update tests files
      - guardrails
      - pytest

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

- [x] architecture decision to implement : migrate user input validation from DTO files to blueprint before db connection. Solved : misunderstood problem (thought dto validation should come after DB connection, it doesn't), problem split in 2 : 1. blueprint checks inputs and 2. DTO checks engine rules validation before opening connection to database
- [ ] no mapped error name for missing parameters in the route request in the Flask services. Works as is but for consistency
- [x] add to api dockerfile "apt install curl" missing. 
- [ ] next iteration of the project : once a frontend implemented, review clean and integrate curl test file to test suite. 
- [x] architecture decision to implement : yml : API service should start after pipeline is executed in production. But implies to think about "dev" profile vs "prod/pipeline" profile. Think about it when time. **DONE** ended up separating pipeline command from dev command in makefile. API starts if database is running, after the pipeline has run. 
- [x] identified ^M presence at the end of some lines therefore => need to strenghten the gitattributes with `* text=auto eol=lf` + adjusted VSCode settings 

**YML**
- **Robustness:**
  - [x]`:?` guards on port variables;
  - [x]`$$` in the healthcheck;
  - [x]`UID`/`GID`.
- [x]**`./SQL` as `:ro` in `db`:** already checked with `grep`, no writes.
- [x]**Lighter client images:** `builder` and `builder_dev` use the full `postgres:16` image when they only need `psql`. This is what creates useless anonymous volumes. Find an image with only `psql`, plus PostGIS if needed.
- [x] **[healthcheck = liveness only]** api healthcheck checks graph readiness guardrails. and starts in build mode fater the builder if needs to, else ignores it. Even if builder fails, the guardrail check will block the api service to run


**Makefile**
- [x]**Goal:** no longer need `make pipeline up` or `make pipeline down` day to day.
- [x]**`make pipeline`:** runs the pipeline, then removes the `loader` and `builder` containers.
- [x]**`make up` and `make down`:** start and stop the working environment.
- [x]**`first run`:** `make build pipeline up`
- [x] harmonize makefile with docker naming conventions
- [x] **[run-sql scoped fail-fast]** Move UID/GID resolution from .env to the `run-sql` Makefile target: `UID=$$(id -u) GID=$$(id -g) docker compose ...` WHY: a `:?` guard can't live in the yaml — Compose interpolates the WHOLE file before filtering profiles (verified: `docker compose config db` fails on `services.builder_dev.user`). Current fix = `${UID:-1000}` defaults. WHY IT WORKS: make recipes run in /bin/sh (GNU make manual: SHELL is never inherited from env), where UID is not readonly (unlike bash). TO CHECK FIRST: `/bin/sh` = dash on the dev machine; UID assignment works.
GAIN: UID/GID lines removable from .env / .env.example.


**.env conventions**
- ~~Currently, dev values live in `.env` and `.env.example`, and test values in `TEST_ENV` in the conftest. Changing a port therefore means knowing two places.~~
- ~~Lead: `TEST_*` variables in `.env`, read by the conftest. Check what common practice is.~~
- [x] Single source of truth solution : config.py. DB vars checked at import, FLASK_* at server start

### backlog short term
- [x] remember to keep sources from raster dataset in a light csv
- [ ] to do before closure : keep track of ALL the sources in DATA/SOURCES.csv (edges and points too)(and bibliography)
- [x] move first step of raster dataset cleaning in "work" file (DATA/work)
- [x] harmonize names of vector layers
- [ ] harmonize documentation with actual edges numbers : about 86k edges, not 76k
- [ ] harmonize documentation "kilometers" vs "kilometres"
- [x] Frenglish: "test_db is a success!" -> proper English message => changed 

### backlog python services (non urgent, works for now)

- [x] **Rename `get_route` → `search_pois` in `pois/blueprint.py`**
      Copy-paste from routes. Not a bug (endpoints stay distinct via blueprint
      name), but misleading and a potential trap for a future url_for().
      Readability.

- [x] **None-guard asymmetry between the two DTOs** (design call to make)
      `routes/dto.py` guards `speed_kmh is None`; `pois/dto.py` does not guard
      `radius_m is None`. If a caller bypasses the blueprint, `None <= 10`
      raises TypeError instead of InvalidRadiusError. The blueprint already
      guarantees non-None → possibly YAGNI. Decide: consistency vs KISS.

- [ ] **Double ST_Transform per row in `pois/repository.py`** (perf, minor)
      ST_X(ST_Transform(geom,4326)) + ST_Y(ST_Transform(geom,4326)) transforms
      the same geometry twice. ST_Transform is IMMUTABLE so the planner MAY
      factor it out, not guaranteed. Negligible on ~1000 POIs. Possible fix:
      CROSS JOIN LATERAL (SELECT ST_Transform(p.geom,4326) AS g).
      Probably YAGNI.

### Python cleanup (Oct 23 – Nov 2) — DONE
- [x] conftest: wait on builder exit code, pytest.exit on build failure, PG_PORT=0
- [x] config.py: single source of truth; DB vars checked at import, FLASK_* at server start
- [x] PG error parsing confined to repositories (e.diag.message_primary)
- [x] shared helpers: utils/coverage.py, utils/validation.py (finite coords, same point)
- [x] DTO validation in __post_init__, before opening the DB connection; NaN/inf rejected
- [x] API params unified: /api/route uses lat_start/lon_start/lat_end/lon_end
- [x] inclusive bounds: speed [10, 25], radius [10, 1000]
- [x] errors: ClientError base class (status_code) + app-level handlers (app/errors.py)
- [x] health check: no leaked libpq details, logged, 503
- [x] POIs expose osm_id (OSM node id); unused fid removed from the model
- [x] pinned runtime deps (= API image), dev deps split; CI on Python 3.11 with .env.example
- [x] whole codebase passes pycodestyle + pyflakes

### Tests backlog
- [ ] split tests: unit / engine (synthetic graph) / data contract (Nevers)
- [ ] pytest.ini: markers, testpaths, pythonpath (replace sys.path.insert)
- [ ] engine test NO_PATH -> 404 (routes + POIs): impossible on Nevers (single component)
- [ ] pytest: long route (~33 km), exists only in the curl suite
- [ ] pytest: unknown URL -> 404 (locks the HTTPException guard in errors.py)
- [ ] assert error messages (cause), not only status codes, in all error tests
- [ ] CI runs pytest only: curl suite is never run automatically
- [ ] missing parameters 400: still a direct return in blueprints, not a ClientError (consistency)

### SQL / guardrails backlog
- [ ] guardrail tests: "expected error" case passes if no error is raised -> sub-block + flag pattern
- [ ] guardrail tests: check WHEN OTHERS in success cases
- [ ] is_within_coverage accepts any point if graph_coverage is empty/NULL (3-valued logic) -> COALESCE
- [ ] snapping: small back-and-forth at route start/end (check in QGIS)
- [ ] typo "BOUNGIN BOX" in the graph master header
- [ ] optional: rename lat1/lon1... in SQL functions (internal, called positionally)

### Data backlog
- [ ] some OSM amenities (culture, catering) might exist only as polygons (need to check number of amenities in polygon gpkg corresponding to the area)

### Docker / env backlog
- [ ] rename PG_PORT -> PG_HOST_PORT (confusion with PGPORT)
- [x] ~~ghost networks after `--profile pipeline up` + `make down`~~ if you have profiles in docker and are told after a crash or a down that you have ghost network, before anything check if you `docker compose -- profile xx up` and a simple `docker compose down`
because if you have exited but non removed services, there's where your supposed ghost networks come from. 
- [ ] loader image: Ubuntu 22.04 `postgresql-client` 14 against a 16 server
      (works, psql warns about the version mismatch)
- [x] (optional, V2/prod) readiness endpoint calling `assert_graph_ready()`:the healthcheck is liveness only, a DB broken *while* the api runs is not detected **DONE**


### Docs backlog
- [ ] README: front screenshot
- [ ] README: list every make target **with its raw `docker compose` equivalent**
      (Windows users may have no make / no Linux shell)
- [ ] `docker.md`:
- [ ] builder / builder_dev no longer use `postgres:16` (Alpine psql client image)
- [ ] rewrite "Orphan networks" with the root cause (partial `down` without profile) instead of the `make re` workaround
- [ ] replace references to `fast`, `re`, `reset`, `run-sql`
- [ ] add: `down` does not remove `run` containers -> `--rm` mandatory
- [ ] `architecture.md`: error flow (ClientError -> `app/errors.py`, 500s logged by the fallback handler, not in blueprints anymore), validation flow (DTO `__post_init__` before `get_db_conn()`)
- [ ] docs: conftest wait strategy, PG_PORT=0, config split (import vs server start)
- [ ] SECURITY.md: FLASK_DEBUG typo ("ture") enables the Werkzeug debugger
- [ ] harmonize documentation with actual edge count: about 86k edges, not 76k
- [ ] harmonize "kilometers" vs "kilometres"
- [ ] rename `biblio` -> `scientific sources`
- [ ] rename `interviews_to_do` -> `user facing interview grid`
- [ ] translate the semi-directive interview grid


### V2 notes
- [ ] pyproject.toml + uv (lock file, Python version management)


### discovered and fixed (June)

- [x] factorized PointOutOfCoverageError in utils/exceptions.py **DONE**
- [x] factorized SamePointError in utils/exceptions.py **DONE**
- [x] first round of documentation update : error_codes_sre.md matches work done up until June 6th. 

### Observability
- [x] [logger.exception] Added logging.getLogger(__name__) + logger.exception
  in the generic `except Exception` handlers of route, POI, and coverage
  blueprints. Unmapped 500s now leave a full server-side traceback in the logs
  while the client still receives a generic error body ("An unexpected error
  occurred"). Rationale: 500s are server-side faults and must be diagnosable;
  4xx (client errors) stay silent. Surfaced during the frontend 500 debug session.

## WHEN TIME (not urgent)

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

4. **OCTOBER**: docker yml and makefile cleanup
5. **THEN**raster service to implement + doc and then close (all other points validated)
- [ ] POI sub-categories
- [ ] Audit all debug functions + add a "debug" category in `engine_functions.md` (check esp big_stress_test.sql)




