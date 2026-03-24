-- SQL/04_graph/02_graph_creation/01_PGRouting_createTopology_graph_creation.sql
-- Create pgRouting topology from the routes_v1 table
-- Generates source/target columns and the routes_v1_vertices_pgr table

\echo ''
\echo '>>> START : /SQL/04_graph/02_graph_creation/01_PGRouting_createTopology_graph_creation.sql'
\echo ''

BEGIN;

-- 1) Reset previous topology state
-- Part 1: Clear existing source/target values to avoid silent pgRouting crashes
-- Part 2: Drop previous vertices table if it exists (idempotent execution)
UPDATE public.routes_v1
SET source = NULL,
    target = NULL;

DROP TABLE IF EXISTS public.routes_v1_vertices_pgr CASCADE;

-- 2) Guardrail: fail fast if routes_v1 is not in a buildable state (missing geom, SRID mismatch, empty table, missing cost columns, etc.)

SELECT assert_graph_preconditions();

-- 3) Create the routing graph
-- Each row represents an edge, each intersection becomes a vertex
-- A spatial tolerance of 1 meter is used to connect nearby but unconnected endpoints
SELECT pgr_createTopology(
  'public.routes_v1',  -- edge table
  routing_topology_tolerance_m(),                   -- snapping tolerance in meters (depends on the graph SRID; a meter-based SRID is strongly recommended, not a degree-based one)
  'geom',              -- geometry column
  'fid'                -- unique edge identifier
);

-- 4) Quick sanity check
-- Ensure that vertices have been created successfully
SELECT COUNT(*) AS nb_vertices
FROM public.routes_v1_vertices_pgr;

COMMIT;


\echo ''
\echo '>>> END : /SQL/04_graph/02_graph_creation/01_PGRouting_createTopology_graph_creation.sql'
\echo ''