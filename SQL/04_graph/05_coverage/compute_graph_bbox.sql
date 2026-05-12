-- /SQL/04_graph/05_coverage/compute_graph_bbox.sql
-- Computes graph coverage and stores the resulting polygon (EPSG:4326) in graph_coverage.

BEGIN;

TRUNCATE graph_coverage;
INSERT INTO graph_coverage (bbox)
SELECT
ST_Transform(
    ST_Buffer(
        ST_ConvexHull(
            ST_Collect(the_geom)
            ),
        500
        ),
    routing_api_srid()
)
FROM routing_vertices;

COMMIT; 