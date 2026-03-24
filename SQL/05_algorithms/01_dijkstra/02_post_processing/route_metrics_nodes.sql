-- SQL/05_algorithms/01_dijkstra/02_post_processing/route_metrics_nodes.sql
--
-- Post-processing: from start/end nodes -> route LINESTRING + distance + estimated time
--
-- Output:
-- - geom_graph     : LINESTRING in routing_graph_srid()
-- - geom_api       : LINESTRING in routing_api_srid()
--
-- Notes:
-- - Uses raw intermediate geometry (geom_graph_raw) to clearly separate
--   computation from output contracts.
-- - Avoid printing large WKT in psql; prefer ST_NPoints / ST_Envelope for debug.

DROP FUNCTION IF EXISTS public.route_metrics_nodes(
  BIGINT, BIGINT, DOUBLE PRECISION
);

CREATE FUNCTION public.route_metrics_nodes(
  start_node BIGINT,
  end_node   BIGINT,
  speed_kmh  DOUBLE PRECISION DEFAULT routing_default_speed_kmh()
)
RETURNS TABLE (
  total_m            DOUBLE PRECISION,
  total_km           DOUBLE PRECISION,
  estimated_time_min DOUBLE PRECISION,
  geom_graph         geometry(LineString),
  geom_api           geometry(LineString)
)
LANGUAGE plpgsql AS $$
DECLARE
  v_edges_count bigint;
  v_total_m     double precision;
  v_geom_raw    geometry(LineString);
BEGIN
  WITH route AS (
    SELECT seq, geom, length_m
    FROM public.dijkstra_only(start_node, end_node)
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
      ) AS arr
    FROM route
  ),
  line AS (
    SELECT ST_MakeLine(arr)::geometry(LineString) AS geom_graph_raw
    FROM pts
  )
  SELECT stats.edges_count, stats.total_m, line.geom_graph_raw
  INTO   v_edges_count,     v_total_m,  v_geom_raw
  FROM stats
  CROSS JOIN line;

  IF v_edges_count = 0 THEN
    RAISE EXCEPTION
      '[ROUTING:NO_PATH] no path found between selected points'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_geom_raw IS NULL THEN
    RAISE EXCEPTION
      '[ROUTING:GEOM_NULL] route geometry could not be constructed'
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
    ST_SetSRID(v_geom_raw, routing_graph_srid())::geometry(LineString) AS geom_graph,
    ST_Transform(ST_SetSRID(v_geom_raw, routing_graph_srid()), routing_api_srid())::geometry(LineString) AS geom_api;

END;
$$;