# to do

## documentation
documentation/
└─ architecture.md

## core routing engine plpgsql

- export_api_route_feature_api() -> in the future change the name for "export_route_api()". 
- fix architecture decision : assert_graph_ready() needs to be called at build time not a query time
- develop assert_graph_ready -> testable version


## POI
once finished : polish it up by adding sub-categories. 

## API
- routes/ in OOP
- put db_connection() in the config file instead of the routes_api.py file. **done**
- rename routes_api.py => blueprint.py **done**

## docker 

- reorganize and simplify the .env **done**