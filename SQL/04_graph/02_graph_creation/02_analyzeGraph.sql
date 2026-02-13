-- SQL/04_graph/02_graph_creation/02_analyzeGraph.sql
-- Topology check on the final graph after cleaning
-- Updates the "chk" field in the vertices table

\echo ''
\echo '>>> START : /SQL/04_graph/02_graph_creation/02_analyzeGraph.sql'
\echo ''

BEGIN;

-- 1) Graph analysis
-- Detects orphan edges, isolated nodes, endpoints, etc.
SELECT pgr_analyzeGraph(
  'public.routes_v1',
  1.0,  -- tolerance (same as createTopology; unit depends on graph SRID)
  'geom',
  'fid'
);

-- 2) Summary of results
SELECT
  COUNT(*) FILTER (WHERE chk = 1) AS nb_isolated_nodes,
  COUNT(*) FILTER (WHERE chk = 2) AS nb_end_nodes,
  COUNT(*) FILTER (WHERE chk = 3) AS nb_invalid_nodes,
  COUNT(*) AS total_nodes
FROM public.routes_v1_vertices_pgr;

COMMIT;


\echo ''
\echo '>>> END : /SQL/04_graph/02_graph_creation/02_analyzeGraph.sql'
\echo ''