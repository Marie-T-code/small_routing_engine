# to do

## documentation
documentation/
└─ architecture.md **done**

## core routing engine plpgsql

- export_api_route_feature_api() -> in the future change the name for "export_route_api()". ALSO dijkstra_only to bdDijkstra_only and dijkstra_snap to bdDijkstra_snap.
- fix architecture decision : assert_graph_ready() needs to be called at build time not a query time **done**
- develop assert_graph_ready -> testable version **DONE**



## POI
once finished : polish it up by adding sub-categories. 

## API
- routes/ in OOP **done**
- put db_connection() in the config file instead of the routes_api.py file. **done**
- rename routes_api.py => blueprint.py **done**
- POI `category` values in French — decide French/English Enums ... 
- message test_db is a success ! is frenglish too. so curl test bd connexion to be revised asap

## docker 

- reorganize and simplify the .env **done**

## NOT NOW BUT WHEN TIME

-  refactor SQL files : 03_injection should be in the docker loader and the name of the files should the be 01_config; 02_graph, ...
(this is going to take time so ... not now)
- QOL : vertice view : 'the_geom' could be changed to 'geom'

## from that damn documentation (prolly will repeat itself I'll clean it up later)


Bascule progressive DROP IF EXISTS → CREATE OR REPLACE quand signatures stables
Refacto make reset ou network external pour le bug des orphan networks **done**
pgr_createTopology : remplacer le reset brute force de source/target par un check d'état

pipeline.md à actualiser **done**
Réviser engine_functions.md, data_quality.md, error_codes_sre.md, graph_build.md **done**