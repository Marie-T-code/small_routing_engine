
# GRAPH ERRORS

| # | error_code | tag | error_message | http_code |
|:-:|------------|-----|---------------|----------:|
| 1 | P0001 | GRAPH:TABLE_MISSING | public.routes_v1 does not exist (run import step) | 500 |
| 2 | P0001 | GRAPH:COL_GEOM_MISSING | public.routes_v1.geom is missing | 500 |
| 3 | P0001 | GRAPH:COL_FID_MISSING | public.routes_v1.fid is missing (required by pgr_createTopology) | 500 |
| 4 | P0001 | GRAPH:COST_COLS_MISSING | cost/reverse_cost columns are missing (run costs configuration step) | 500 |
| 5 | P0001 | GRAPH:GEOM_ALL_NULL | routes_v1.geom contains no non-NULL geometries | 500 |
| 6 | P0001 | GRAPH:SRID_MISMATCH | routes_v1.geom SRID is X, expected Y (routing_graph_srid()) | 500 |
| 7 | P0001 | GRAPH:LENGTH_M_NULLS | routes_v1.length_m contains NULL values (run 006_add_length_m.sql) | 500 |


# ROUTING ERRORS

| # | error_code | tag | error_message | http_code |
|:-:|------------|-----|---------------|----------:|
| 8 | P0001 | ROUTING:GRAPH_NOT_BUILT | graph not built / vertices missing | 500 |
| 9 | P0001 | ROUTING:NO_PATH | no path found between selected points | 404 |
|10 | P0001 | ROUTING:GEOM_NULL | route geometry could not be constructed | 500 |