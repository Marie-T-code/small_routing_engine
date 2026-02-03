-- debug/XX_dijkstra_snap_debug.sql
-- Purpose: Same routing logic as dijkstra_snap, but with additional
--          algorithm-level fields (cost, agg_cost) exposed.
-- Useful for validating cost / reverse_cost configuration and tuning.

CREATE OR REPLACE FUNCTION dijkstra_snap_debug(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
)
RETURNS TABLE (
  seq       INTEGER,
  edge_id   BIGINT,
  cost      DOUBLE PRECISION,
  agg_cost  DOUBLE PRECISION,
  geom      geometry(LineString, routing_graph_srid()),
  length_m  DOUBLE PRECISION
)
LANGUAGE plpgsql AS $$
DECLARE
  s BIGINT;
  t BIGINT;
BEGIN
  -- Snap input coordinates to nearest graph vertices
  s := snap_to_nearest_node(lat1, lon1);
  t := snap_to_nearest_node(lat2, lon2);

  -- Run bidirectional Dijkstra and join edge geometries
  RETURN QUERY
  SELECT
    d.seq,
    d.edge AS edge_id,
    d.cost,
    d.agg_cost,
    r.geom,
    r.length_m
  FROM pgr_bdDijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    s, t,
    true
  ) AS d
  JOIN routing_edges AS r
    ON d.edge = r.id
  WHERE d.edge <> -1
  ORDER BY d.seq;

END;
$$;
