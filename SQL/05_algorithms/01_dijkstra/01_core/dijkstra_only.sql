-- SQL/05_algorithms/01_dijkstra/01_core/dijkstra_only.sql
--
-- Purpose: Core routing function
-- Input: start_node, end_node (vertex ids)
-- Output: ordered path edges with geometry and per-edge length (EPSG:routing_graph_srid())
-- algorithm = bdDijkstra preferred for optimisation purposes here. Every function in this folder will use bdDijkstra instead of dijkstra.

DROP FUNCTION IF EXISTS dijkstra_only(BIGINT, BIGINT);

CREATE FUNCTION dijkstra_only(
  start_node BIGINT,
  end_node   BIGINT
)
RETURNS TABLE (
  seq      INTEGER,
  edge_id  BIGINT,
  cost     DOUBLE PRECISION,
  geom     geometry(LineString),
  length_m DOUBLE PRECISION
)
LANGUAGE sql AS $$
  SELECT
    d.seq,
    d.edge AS edge_id,
    d.cost,
    ST_SetSRID(r.geom, routing_graph_srid())::geometry(LineString) AS geom,
    r.length_m::DOUBLE PRECISION AS length_m
  FROM pgr_bdDijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    start_node, end_node, true
  ) AS d
  JOIN routing_edges AS r
    ON d.edge = r.id
  WHERE d.edge <> -1
  ORDER BY d.seq;
$$;
