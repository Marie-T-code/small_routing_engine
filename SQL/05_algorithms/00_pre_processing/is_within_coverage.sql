-- /SQL/05_algorithms/00_pre_processing/is_within_coverage.sql
-- creates a point from users input and returns true if said point is within the graph coverage. 

DROP FUNCTION IF EXISTS is_within_coverage(DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION is_within_coverage(
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION
    )

RETURNS VOID


AS $$
DECLARE
    p_input geometry;
BEGIN
    --prepare point in API SRID
    p_input := 
    ST_SetSRID(
        ST_MakePoint(lon, lat), routing_api_srid()
        );

    IF NOT (SELECT ST_Within(p_input, bbox) FROM graph_coverage) THEN
        RAISE EXCEPTION '[COVERAGE:OUT_OF_BOUNDS] Point (%, %) is outside graph coverage area.', lat, lon
        USING ERRCODE = 'P0001';
    END IF; 
END; 

$$ LANGUAGE plpgsql;

