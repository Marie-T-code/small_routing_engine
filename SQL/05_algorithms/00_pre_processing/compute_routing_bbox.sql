-- SQL/05_algorithms/00_pre_processing/compute_routing_bbox.sql
--
-- Purpose: Compute the bounding box used to filter routing edges before
--          Dijkstra exploration. Built around two graph vertices,
--          enlarged by a buffer proportional to their euclidean distance.
--
-- Inputs:  geom_s, geom_t — vertex geometries (Point, 2154) from snap_to_nearest_node.
-- Output:  geometry(Polygon, 2154) — bounding box in EPSG:routing_graph_srid().
--
-- Notes:
-- - Buffer is adaptive: distance(geom_s, geom_t) * routing_bbox_buffer_ratio().
-- - On long trips, the bbox may exceed the graph extent; this is acceptable
--   (filtering becomes a no-op rather than a constraint that loses paths).
-- - Used by dijkstra_only(...) via the optional bbox parameter.
--
-- Dependencies:
--   routing_bbox_buffer_ratio()

\echo ''
\echo '>>> START : SQL/05_algorithms/00_pre_processing/compute_routing_bbox.sql'
\echo ''

DROP FUNCTION IF EXISTS compute_routing_bbox(geometry, geometry);

CREATE FUNCTION compute_routing_bbox(
    geom_s geometry(Point, 2154),
    geom_t geometry(Point, 2154)
)
RETURNS geometry(Polygon, 2154)
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT ST_Buffer(
    ST_Envelope(ST_MakeLine(geom_s, geom_t)),
    ST_Distance(geom_s, geom_t) * routing_bbox_buffer_ratio(),
    'endcap=square join=mitre'
    );
$$;

\echo ''
\echo 'compute_routing_bbox function created'
\echo ''

\echo ''
\echo '<<< END   : SQL/05_algorithms/00_pre_processing/compute_routing_bbox.sql'
\echo ''