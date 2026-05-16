# TO DO

## CURRENT FOCUS: BBOXES + ARCHITECTURE DECISION (MAY)
- [ ] Add bboxes to routing engine
- [ ] swap bd_dijkstra for dijkstra + reverse_cost
   Migrate to dijkstra + reverse_cost for one-ways (cleaner, standard pgRouting pattern)
- [ ] refactor routing functions to use reverse_cost
- [ ] Update architecture.md and functions.md to document decision

## NEXT: CURL TEST SUITE (post-bboxes)
- [ ] Curl test end-to-end routes/ (with bboxes)
- [ ] Curl test POI search
- [ ] Complete API test suite (routes + POIs + health)

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
2. **NEXT**: Curl test suite (post-bboxes)
3. **NEXT**: Pytest + testcontainers
4. **NEXT**: Simple frontend
5. **NEXT**: Typing + Pydantic v2 + FastAPI migration
6. **NEXT**: Performance + async + connection pooling
