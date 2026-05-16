-- 
--
-- Purpose: Same routing logic as dijkstra_snap, but with additional
--          algorithm-level fields (cost, agg_cost) exposed.
-- Useful for validating cost / reverse_cost configuration and tuning.

DROP FUNCTION IF EXISTS dijkstra_snap_debug(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION dijkstra_snap_debug(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
)
RETURNS TABLE (
  seq       INTEGER,
  edge_id   BIGINT,
  cost      DOUBLE PRECISION,
  agg_cost  DOUBLE PRECISION,
  geom      geometry(LineString),
  length_m  DOUBLE PRECISION
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

  RETURN QUERY
  SELECT
    d.seq,
    d.edge_id,
    d.cost,
    SUM(d.cost) OVER (ORDER BY d.seq) AS agg_cost,
    d.geom,
    d.length_m
  FROM dijkstra_only(s_id, t_id, bbox) AS d;

  IF NOT FOUND THEN
  RAISE NOTICE 'bbox path not found, retrying on full graph...';
  -- Retry without bbox (full graph)
    RETURN QUERY
    SELECT  
    d.seq,
    d.edge_id,
    d.cost,
    SUM(d.cost) OVER (ORDER BY d.seq) AS agg_cost,
    d.geom,
    d.length_m
    FROM public.dijkstra_only(s_id, t_id, NULL) AS d;
  
    -- If still no path: truly disconnected vertices
    IF NOT FOUND THEN
      RAISE EXCEPTION
        '[ROUTING:NO_PATH] no path found between selected points'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

END;
$$;
