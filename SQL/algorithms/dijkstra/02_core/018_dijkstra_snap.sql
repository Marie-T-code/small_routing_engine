-- XX018_dijkstra_snap.sql
-- Itinerary from point A to point B with snapping
-- Minimal core output (no GeoJSON): segments + meters, intended for API + post-processing.

CREATE OR REPLACE FUNCTION dijkstra_snap(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
)
RETURNS TABLE (
  seq      INTEGER,
  edge     BIGINT,
  cost     DOUBLE PRECISION,
  geom     geometry(LineString, 2154),
  length_m DOUBLE PRECISION
)
LANGUAGE plpgsql AS $$
DECLARE
  s BIGINT;
  t BIGINT;
BEGIN
  s := snap_to_nearest_node(lat1, lon1);
  t := snap_to_nearest_node(lat2, lon2);

  RETURN QUERY
  SELECT * FROM dijkstra_only(s, t);

  RETURN;
END;
$$;
