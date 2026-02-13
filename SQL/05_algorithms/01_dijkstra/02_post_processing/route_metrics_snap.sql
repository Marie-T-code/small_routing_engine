-- SQL/05_algorithms/01_dijkstra/02_post_processing/route_metrics_snap.sql
--
-- Wrapper: lat/lon -> snap -> nodes -> metrics
-- Note: printing large geometries as WKT in psql can trigger the pager / appear to “hang”. Prefer ST_NPoints, ST_Envelope, or file export for debugging. A streaming GeoJSON export can be added if a detailed per-segment output is needed.
-- if nothing comes up in the terminal check : 
-- SELECT length(ST_AsText(geom_api)) AS wkt_chars

DROP FUNCTION IF EXISTS public.route_metrics_snap(
  DOUBLE PRECISION, DOUBLE PRECISION,
  DOUBLE PRECISION, DOUBLE PRECISION,
  DOUBLE PRECISION
);

CREATE FUNCTION public.route_metrics_snap(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION,
  speed_kmh DOUBLE PRECISION DEFAULT routing_default_speed_kmh()
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
  s BIGINT;
  t BIGINT;
BEGIN
  s := public.snap_to_nearest_node(lat1, lon1);
  t := public.snap_to_nearest_node(lat2, lon2);

  RETURN QUERY
  SELECT *
  FROM public.route_metrics_nodes(s, t, speed_kmh);
END;
$$;


