
# GRAPH PRE_CONDITIONS ERRORS

| # | error_code | tag | error_message | http_code |
|:-:|------------|-----|---------------|----------:|
| 1 | P0001 | GRAPH_PRECONDITIONS:TABLE_MISSING | public.routes_v1 does not exist (run import step) | 500 |
| 2 | P0001 | GRAPH_PRECONDITIONS:COL_GEOM_MISSING | public.routes_v1.geom is missing | 500 |
| 3 | P0001 | GRAPH_PRECONDITIONS:COL_FID_MISSING | public.routes_v1.fid is missing (required by pgr_createTopology) | 500 |
| 4 | P0001 | GRAPH_PRECONDITIONS:COST_COLS_MISSING | cost/reverse_cost columns are missing (run costs configuration step) | 500 |
| 5 | P0001 | GRAPH_PRECONDITIONS:GEOM_ALL_NULL | routes_v1.geom contains no non-NULL geometries | 500 |
| 6 | P0001 | GRAPH_PRECONDITIONS:SRID_MISMATCH | routes_v1.geom SRID is %, expected %. | 500 |
| 7 | P0001 | GRAPH_PRECONDITIONS:LENGTH_M_NULLS | routes_v1.length_m contains NULL values (run 006_add_length_m.sql) | 500 |


# GRAPH STATE ERRORS

| # | error_code | tag | error_message | http_code |
|:-:|------------|-----|---------------|----------:|
| 8 | P0001 | GRAPH_STATE:VIEWS_MISSING | routing_edges view missing (run MASTER_GRAPH) | 500 |
| 9 | P0001 | GRAPH_STATE:VIEWS_MISSING | routing_vertices view missing (run MASTER_GRAPH) | 500 |
|10 | P0001 | GRAPH_STATE:CRITICAL_COLS_MISSING | routing_edges missing critical columns (source/target/cost/reverse_cost/geom). | 500 |
|11 | P0001 | GRAPH_STATE:CRITICAL_COLS_MISSING | routing_vertices missing id column. | 500 |
|12 | P0001 | GRAPH_STATE:CRITICAL_COLS_MISSING | routing_vertices missing the_geom column. | 500 |
|13 | P0001 | GRAPH_STATE:EMPTY | routing_edges is empty (run MASTER_GRAPH). | 500 |
|14 | P0001 | GRAPH_STATE:EMPTY | routing_vertices is empty (run MASTER_GRAPH). | 500 |
|15 | P0001 | GRAPH_STATE:TOPOLOGY_NULL | routing_edges has NULL source/target (topology not built). | 500 |
|16 | P0001 | GRAPH_STATE:COST_NULL | routing_edges has NULL cost/reverse_cost (run costs configuration step). | 500 |
|17 | P0001 | GRAPH_STATE:GEOM_ALL_NULL  | routing_edges has no non-NULL geometries. | 500 |
|18 | P0001 | GRAPH_STATE:SRID_MISMATCH  | routing_edges.geom SRID is %, expected %. | 500 |


# ROUTING ERRORS

| # | error_code | tag | error_message | http_code |
|:-:|------------|-----|---------------|----------:|
|19 | P0001 | ROUTING:NO_PATH | no path found between selected points | 404 |
|20 | P0001 | ROUTING:GEOM_NULL | route geometry could not be constructed | 500 |