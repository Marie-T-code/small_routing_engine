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
BEGIN
  RETURN QUERY
  WITH segs AS (
    -- Ordered path segments from core routing
    SELECT seq, geom, length_m
    FROM public.dijkstra_only(start_node, end_node)
    ORDER BY seq
  ),
  pts AS (
    -- Build ordered list of points (start + all segment endpoints)
    SELECT
      array_prepend(
        (SELECT ST_StartPoint(geom)
         FROM segs
         ORDER BY seq
         LIMIT 1),
        array_agg(ST_EndPoint(geom) ORDER BY seq)
      ) AS arr
    FROM segs
  ),
  line AS (
    -- Raw geometry: no SRID contract here
    SELECT ST_MakeLine(arr) AS geom_graph_raw
    FROM pts
  ),
  tot AS (
    -- Total length in meters
    SELECT COALESCE(SUM(length_m), 0)::double precision AS total_m
    FROM segs
  )
  SELECT
    tot.total_m,
    (tot.total_m / 1000.0)::double precision AS total_km,
    CASE
      WHEN speed_kmh IS NULL OR speed_kmh <= 0 THEN NULL
      ELSE ((tot.total_m / 1000.0) / speed_kmh * 60.0)::double precision
    END AS estimated_time_min,

    -- Graph output: explicit SRID contract
    ST_SetSRID(
      line.geom_graph_raw,
      routing_graph_srid()
    )::geometry(LineString) AS geom_graph,

    -- API output: transform from graph SRID to API SRID
    ST_Transform(
      ST_SetSRID(line.geom_graph_raw, routing_graph_srid()),
      routing_api_srid()
    )::geometry(LineString) AS geom_api

  FROM tot
  CROSS JOIN line;

  -- Security: path must exist
  IF NOT FOUND THEN
    RAISE EXCEPTION
      '[ROUTING:NO_PATH] no path found between selected points'
      USING ERRCODE = 'P0001';
  END IF;

  -- Security: route geometry must be constructible
  IF geom_graph IS NULL THEN
    RAISE EXCEPTION
      '[ROUTING:GEOM_NULL] route geometry could not be constructed'
      USING ERRCODE = 'P0001';
  END IF;
END;
$$;
