-- SQL/05_algorithms/00_pre_processing/snap_to_nearest_node.sql
--
-- Purpose: Snap an input geographic point (lat/lon in EPSG:4326)
--          to the nearest graph vertex and return its id and geometry.
--
-- Returns: TABLE (id BIGINT, the_geom geometry(Point, 2154))
--          - id: vertex identifier in routing_vertices
--          - the_geom: vertex geometry in EPSG:routing_graph_srid()
--
-- Notes:
-- - Uses KNN (<->) for efficient nearest-neighbor lookup.
-- - Returned geometry avoids downstream functions having to re-query routing_vertices.

DROP FUNCTION IF EXISTS snap_to_nearest_node(DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION snap_to_nearest_node(
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION
)
RETURNS TABLE (
    id BIGINT,
    the_geom geometry(Point, 2154)
)
AS $$
DECLARE
    p_graph geometry;
BEGIN
    -- Prepare point in graph SRID
    p_graph := ST_Transform(
        ST_SetSRID(ST_MakePoint(lon, lat), routing_api_srid()),
        routing_graph_srid()
    );

    -- KNN snap: return both id and geometry
    RETURN QUERY
    SELECT v.id, v.the_geom
    FROM public.routing_vertices v
    ORDER BY v.the_geom <-> p_graph
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;