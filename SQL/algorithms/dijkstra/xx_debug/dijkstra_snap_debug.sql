-- debug/XX_dijkstra_snap_debug.sql
-- Same routing as core dijkstra_snap, but returns additional algorithmic fields (agg_cost)
-- Useful to validate cost / reverse_cost tuning.

CREATE OR REPLACE FUNCTION dijkstra_snap_debug(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
)
RETURNS TABLE (
  seq       INTEGER,
  edge_id   BIGINT,
  cost      DOUBLE PRECISION,
  agg_cost  DOUBLE PRECISION,
  geom      geometry(LineString, 2154),
  length_m  DOUBLE PRECISION
)
LANGUAGE plpgsql AS $$
DECLARE
  s BIGINT;
  t BIGINT;
BEGIN
  -- Snap entrée -> noeuds du graphe
  s := snap_to_nearest_node(lat1, lon1);
  t := snap_to_nearest_node(lat2, lon2);

  -- Route (bidirectionnelle) + join géométrie
  RETURN QUERY
  SELECT
    d.seq,
    d.edge AS edge_id,
    d.cost,
    d.agg_cost,
    r.geom,
    ST_Length(r.geom)::DOUBLE PRECISION AS length_m
  FROM pgr_bdDijkstra(
    'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
    s, t,
    true
  ) AS d
  JOIN routes_v1 AS r
    ON d.edge = r.fid
  WHERE d.edge <> -1
  ORDER BY d.seq;

  RETURN;
END;
$$;
