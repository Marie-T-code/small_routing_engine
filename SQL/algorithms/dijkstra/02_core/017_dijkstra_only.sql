-- XX017_dijkstra_only.sql
-- Core routing: start_node/end_node -> edges + geom + length


CREATE OR REPLACE FUNCTION dijkstra_only(
  start_node BIGINT,
  end_node   BIGINT
)
RETURNS TABLE (
  seq      INTEGER,
  edge     BIGINT,
  cost     DOUBLE PRECISION,
  geom     geometry(LineString, 2154),
  length_m DOUBLE PRECISION
)
LANGUAGE sql AS $$
  SELECT
    d.seq,
    d.edge,
    d.cost,
    r.geom,
    ST_Length(r.geom)::DOUBLE PRECISION AS length_m
  FROM pgr_bdDijkstra(
    'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
    start_node, end_node, true
  ) AS d
  JOIN routes_v1 AS r
    ON d.edge = r.fid
  WHERE d.edge <> -1
  ORDER BY d.seq;
$$;
