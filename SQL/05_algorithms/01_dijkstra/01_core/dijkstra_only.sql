-- SQL/05_algorithms/01_dijkstra/01_core/dijkstra_only.sql
--
-- Purpose: Core routing function with optional bounding box filtering
-- Input: start_node, end_node (vertex ids), optional bbox (Polygon in routing_graph_srid())
-- Output: ordered path edges with geometry and per-edge length (EPSG:routing_graph_srid())
-- Notes:
-- - Algorithm: pgr_bdDijkstra (bidirectional) for better performance
-- - bbox parameter filters edges spatially before Dijkstra exploration
-- - bbox DEFAULT NULL: when NULL, routes on the full graph (no filtering)

DROP FUNCTION IF EXISTS dijkstra_only(BIGINT, BIGINT);
DROP FUNCTION IF EXISTS dijkstra_only(BIGINT, BIGINT, geometry);

CREATE FUNCTION dijkstra_only(
  start_node BIGINT,
  end_node   BIGINT, 
  bbox       geometry DEFAULT NULL
)
RETURNS TABLE (
  seq      INTEGER,
  edge_id  BIGINT,
  cost     DOUBLE PRECISION,
  geom     geometry(LineString),
  length_m DOUBLE PRECISION
)
LANGUAGE plpgsql AS $$
DECLARE
  edges_query TEXT;
BEGIN
  -- Build edges query with optional bbox filtering
  IF bbox IS NULL THEN
    edges_query := 'SELECT id, source, target, cost, reverse_cost FROM routing_edges';
  ELSE
    edges_query := format(
      'SELECT id, source, target, cost, reverse_cost FROM routing_edges WHERE geom && %L',
      bbox
    );
  END IF;
  -- Execute Dijkstra and return results
  RETURN QUERY
  SELECT
    d.seq,
    d.edge AS edge_id,
    d.cost,
    ST_SetSRID(r.geom, routing_graph_srid())::geometry(LineString) AS geom,
    r.length_m::DOUBLE PRECISION AS length_m
  FROM pgr_bdDijkstra(
    edges_query,
    start_node, end_node, true
  ) AS d
  JOIN routing_edges AS r
    ON d.edge = r.id
  WHERE d.edge <> -1
  ORDER BY d.seq;

END
$$;
