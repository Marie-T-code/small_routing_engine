-- SQL/05_algorithms/01_dijkstra/01_core/dijkstra_snap.sql
--
-- Purpose: Route from point A to point B with snapping (inputs in routing_api_srid() (default: EPSG:4326)).
-- Output: Minimal core result (no GeoJSON): ordered segments with geometry in EPSG:routing_graph_srid().
-- Notes:
-- - Snapping is performed against routing_vertices (graph vertices).
-- - Bounding box optimization is applied to filter edges before Dijkstra exploration.
-- - If bbox filtering fails to find a path, retries on the full graph (fallback strategy).
-- - The returned result is the raw path from dijkstra_only(start_node, end_node, bbox).

DROP FUNCTION IF EXISTS dijkstra_snap(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE FUNCTION dijkstra_snap(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
)
RETURNS TABLE (
  seq      INTEGER,
  edge_id     BIGINT,
  cost     DOUBLE PRECISION,
  geom     geometry(LineString),
  length_m DOUBLE PRECISION
)
LANGUAGE plpgsql AS $$
DECLARE
  s_id BIGINT;
  t_id BIGINT;
  s_geom geometry;
  t_geom geometry;
  bbox geometry;
BEGIN
  SELECT id, the_geom INTO s_id, s_geom FROM snap_to_nearest_node(lat1, lon1);
  SELECT id, the_geom INTO t_id, t_geom FROM snap_to_nearest_node(lat2, lon2);

  bbox := compute_routing_bbox(s_geom, t_geom);
  


  -- Return the path (if any)
  RETURN QUERY
  SELECT * FROM public.dijkstra_only(s_id, t_id, bbox);

  IF NOT FOUND THEN
  -- Retry without bbox (full graph)
    RETURN QUERY
    SELECT * FROM public.dijkstra_only(s_id, t_id, NULL);
  
    -- If still no path: truly disconnected vertices
    IF NOT FOUND THEN
      RAISE EXCEPTION
        '[ROUTING:NO_PATH] no path found between selected points'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

END;
$$;
