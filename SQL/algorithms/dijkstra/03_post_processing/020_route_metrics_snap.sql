-- 021_route_metrics_snap.sql
-- Wrapper: lat/lon -> snap -> nodes -> metrics
-- Note: printing large geometries as WKT in psql can trigger the pager / appear to “hang”. Prefer ST_NPoints, ST_Envelope, or file export for debugging. A streaming GeoJSON export can be added if a detailed per-segment output is needed.
-- if nothing comes up in the terminal check : 
-- SELECT length(ST_AsText(geom_4326)) AS wkt_chars
-- FROM route_metrics_snap(<lat1>, <lon1>, <lat2>, <lon2>);

CREATE OR REPLACE FUNCTION route_metrics_snap(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION,
  speed_kmh DOUBLE PRECISION DEFAULT 15.0
)
RETURNS TABLE (
  total_m            DOUBLE PRECISION,
  total_km           DOUBLE PRECISION,
  estimated_time_min DOUBLE PRECISION,
  geom_2154          geometry(LineString, 2154),
  geom_4326          geometry(LineString, 4326)
)
LANGUAGE plpgsql AS $$
DECLARE
  s BIGINT;
  t BIGINT;
BEGIN
  s := snap_to_nearest_node(lat1, lon1);
  t := snap_to_nearest_node(lat2, lon2);

  RETURN QUERY
  SELECT * FROM route_metrics_nodes(s, t, speed_kmh);

  RETURN;
END;
$$;
