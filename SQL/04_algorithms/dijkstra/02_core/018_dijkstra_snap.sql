-- XX018_dijkstra_snap.sql
-- Purpose: Route from point A to point B with snapping (nputs in routing_api_srid() (default: EPSG:4326)).
-- Output: Minimal core result (no GeoJSON): ordered segments with geometry in EPSG:routing_graph_srid().
-- Notes:
-- - Snapping is performed against routing_vertices (graph vertices).
-- - The returned result is the raw path from dijkstra_only(start_vid, end_vid).

CREATE OR REPLACE FUNCTION dijkstra_snap(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
)
RETURNS TABLE (
  seq      INTEGER,
  edge_id     BIGINT,
  cost     DOUBLE PRECISION,
  geom     geometry(LineString, routing_graph_srid()),
  length_m DOUBLE PRECISION
)
LANGUAGE plpgsql AS $$
DECLARE
  s BIGINT;
  t BIGINT;
BEGIN
  s := public.snap_to_nearest_node(lat1, lon1);
  t := public.snap_to_nearest_node(lat2, lon2);


  -- Return the path (if any)
  RETURN QUERY
  SELECT * FROM public.dijkstra_only(s, t);

  -- If the previous RETURN QUERY returned 0 rows: no path
  IF NOT FOUND THEN
    RAISE EXCEPTION
      '[ROUTING:NO_PATH] no path found between selected points'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT * FROM public.dijkstra_only(s, t);

END;
$$;
