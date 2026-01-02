
CREATE OR REPLACE FUNCTION snap_to_nearest_node(
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION
)
RETURNS BIGINT AS $$
DECLARE
    snapped_id BIGINT;
BEGIN
    SELECT id
    INTO snapped_id
    FROM routes_v1_vertices_pgr
    ORDER BY the_geom <-> ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 2154)
    LIMIT 1;

    RETURN snapped_id;
END;
$$ LANGUAGE plpgsql;