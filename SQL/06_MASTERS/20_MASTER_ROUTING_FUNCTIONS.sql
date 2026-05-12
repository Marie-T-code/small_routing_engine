-- /SQL/06_MASTERS/20_MASTER_ROUTING_FUNCTIONS.sql

\echo ''
\echo '>>> START : /SQL/06_MASTERS/20_MASTER_ROUTING_FUNCTIONS.sql'
\echo ''


\echo '--- PREPROCESSING ---'
\echo '---------------------'

\echo 'creates a point from users input and returns true if said point is within the graph coverage.'
\i /SQL/05_algorithms/00_pre_processing/is_within_coverage.sql

\echo '--- compute_routing_bbox function : Compute bounding box for spatial filtering ---'
\i /SQL/05_algorithms/00_pre_processing/compute_routing_bbox.sql

\echo '--- snap function : Snap an input geographic point (lat/lon in EPSG:4326) to the nearest graph vertex and return its vertex id. ---'
\i /SQL/05_algorithms/00_pre_processing/snap_to_nearest_node.sql




\echo '--- CORE ---'
\echo '------------'


\echo '--- Core routing function ---'
\i /SQL/05_algorithms/01_dijkstra/01_core/dijkstra_only.sql

\echo '--- dijkstra_snap function : Route from point A to point B with snapping ---'
\i /SQL/05_algorithms/01_dijkstra/01_core/dijkstra_snap.sql


\echo '--- POSTPROCESSING ---'
\echo '----------------------'



\echo '--- route_metrics function : Wrapper: lat/lon -> snap ->  -> route LINESTRING + distance + estimated time ---'
\i /SQL/05_algorithms/01_dijkstra/02_post_processing/route_metrics.sql

\echo '--- export_route_api function : Returns a single GeoJSON Feature (API SRID, default: EPSG:4326) with user-facing metrics. ---'
\i SQL/05_algorithms/01_dijkstra/04_export_modes/export_route_api.sql

\echo ''
\echo '>>> END : /SQL/06_MASTERS/20_MASTER_ROUTING_FUNCTIONS.sql'
\echo ''