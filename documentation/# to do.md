# TO DO

## CURRENT FOCUS: BBOXES + ARCHITECTURE DECISION (MAY)
- [X] Add bboxes to routing engine **DONE**
- [X] swap bd_dijkstra for dijkstra + reverse_cost **DONE**
   Migrate to dijkstra + reverse_cost for one-ways (cleaner, standard pgRouting pattern) **DONE**
- [X]refactor routing functions to use reverse_cost **DONE**
- [ ] Update architecture.md and functions.md to document decision

### SPOTTED PROBLEMS SOLVED(MAY)

- [X] Simplified the 01_PGRouting_createTopology_graph_creation.sql
- [X] Overengineered the same file, saved it for a future "devtools" file. 
- [X] QOL : "make psql" (enter the psql command in the terminal) + "make export" (make export + path/to/file, uses the dev_tools docker service)
- [X]fixed 'make re' (reset + fast) from the makefile **DONE**

## NEXT: CURL TEST SUITE (post-bboxes)
- [X] Curl test end-to-end routes/ (with bboxes) (documented) **DONE**
- [X] Curl test POI search **DONE**
- [X] Complete API test suite (routes + POIs + health) **DONE**
- [X] make test-api command added in the Makefile **DONE**

## THEN: PYTEST + TESTCONTAINERS
- [ ] Wrap PL/pgSQL test functions (assert_graph_preconditions_on, assert_graph_ready_on) in pytest
- [ ] Set up testcontainers for isolated test runs
- [ ] Document test strategy in functions.md


## API CLEANUPS (low priority — when time)
- [ ] Fix frenglish: "test_db is a success!" → proper English message
- [ ] POI `category` values: decide French vs English for Enums
- [X] Rename export_api_route_feature_api() → export_route_api() **DONE**
- [ ] Add sub-categories to POI data
- [X] Remove bd_ prefix and use pgr_dijkstra + reverese costs on oneway **DONE**
- [ ] Audit on all debug functions + add "debug" category in the functions.md. 

## DOCUMENTATION
- [ ] functions.md — finish function reference
- [ ] Full doc review end of May (add new features, remove unused)

## SQL REFACTORING (not now — when time)
- [ ] pgr_createTopology: replace brute force reset with state check (IF NOT EXISTS)
- [ ] Progressive change DROP IF EXISTS → CREATE OR REPLACE when signatures stable
- [ ] Refactor SQL file numbering (03_injection → docker loader, renumber 01_config, 02_graph...)
- [ ] QOL: vertices view 'the_geom' → 'geom'

## ROADMAP (validated)
1. **MAY**: BBoxes + architecture decision
2. **MAY-> ?**: Curl test suite (post-bboxes)
3. **NEXT**: Pytest + testcontainers
4. **NEXT**: Simple frontend
5. **NEXT**: Typing + Pydantic v2 + FastAPI migration
6. **NEXT**: Performance + async + connection pooling


## backlog : 


