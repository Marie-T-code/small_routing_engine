-- SQL/05_algorithms/01_dijkstra/02_post_processing/route_metrics.sql
--
-- Post-processing: routing table (dijkstra_snap() -> route LINESTRING + distance + estimated time
--
-- Input  : lat1, lon1, lat2, lon2 (EPSG:4326) + speed_kmh
-- Output : total_m, total_km, estimated_time_min, route_geom_graph (2154), route_geom_api (4326)
--
-- Notes:
-- - Uses raw intermediate geometry (geom_graph_raw) to clearly separate computation from output contracts.
-- - Avoid printing large WKT in psql; prefer ST_NPoints / ST_Envelope for debug.
-- - Strict dedup (ST_RemoveRepeatedPoints) removes coincident vertices at edge
--   junctions caused by ST_EndPoint on edges not reoriented to traversal direction.
--   Edges are 2-point segments, so strict dedup suffices (no intermediate points to misorder).

DROP FUNCTION IF EXISTS public.route_metrics(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION
);


CREATE FUNCTION public.route_metrics(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION,
    speed_kmh DOUBLE PRECISION DEFAULT routing_default_speed_kmh()
)
RETURNS TABLE(
    total_m            DOUBLE PRECISION, 
    total_km           DOUBLE PRECISION,
    estimated_time_min DOUBLE PRECISION, 
    route_geom_graph         geometry(Linestring), 
    route_geom_api           geometry(Linestring)
    
)
LANGUAGE plpgsql AS $$
DECLARE
    v_edges_count bigint;
    v_total_m     double precision;
    v_route_geom_raw    geometry(LineString);
BEGIN
    WITH route AS (
        SELECT seq, geom, length_m
        FROM public.dijkstra_snap(lat1, lon1, lat2, lon2)
        ORDER BY seq
    ),
    stats AS (
        SELECT
            COUNT(*)::bigint AS edges_count,
            COALESCE(SUM(length_m), 0)::double precision AS total_m
        FROM route
    ),
    pts AS (
        SELECT
            array_prepend(
                (SELECT ST_StartPoint(geom) FROM route ORDER BY seq LIMIT 1),
                array_agg(ST_EndPoint(geom) ORDER BY seq)
            ) as arr
        FROM route
    ),
    line AS (
        SELECT ST_RemoveRepeatedPoints(ST_Makeline(arr))::geometry(Linestring) AS route_geom_graph_raw
        FROM pts
    )
    SELECT stats.edges_count, stats.total_m, line.route_geom_graph_raw
        INTO v_edges_count, v_total_m, v_route_geom_raw
        FROM stats
        CROSS JOIN line;
    
    IF v_edges_count = 0 THEN
        RAISE EXCEPTION
            '[ROUTING:NO_PATH] no path found between selected points'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN QUERY
    SELECT
        v_total_m AS total_m,
        (v_total_m / 1000.0)::double precision AS total_km,
    CASE
        WHEN speed_kmh IS NULL OR speed_kmh <= 0 THEN NULL
        ELSE ((v_total_m / 1000.0) / speed_kmh * 60.0)::double precision
    END AS estimated_time_min,
    ST_SetSRID(v_route_geom_raw, routing_graph_srid())::geometry(LineString) AS route_geom_graph,
    ST_Transform(ST_SetSRID(v_route_geom_raw, routing_graph_srid()), routing_api_srid())::geometry(LineString) AS route_geom_api;
END;
$$;