-- SQL/05_algorithms/00_pre_processing/snap_to_nearest_node.sql
--
-- Purpose: Snap an input geographic point (lat/lon in EPSG:4326)
--          to the nearest graph vertex and return its vertex id.

CREATE OR REPLACE FUNCTION snap_to_nearest_node(
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION
)
RETURNS BIGINT AS $$
DECLARE
    snapped_id BIGINT;
    p_graph geometry;
BEGIN

    -- Prepare point in graph SRID
    p_graph := ST_Transform(
        ST_SetSRID(ST_MakePoint(lon, lat), routing_api_srid()),
        routing_graph_srid()
    );

    -- 2) KNN snap
    SELECT id
    INTO snapped_id
    FROM public.routing_vertices
    ORDER BY the_geom <-> p_graph
    LIMIT 1;

    RETURN snapped_id;
END;
$$ LANGUAGE plpgsql;
