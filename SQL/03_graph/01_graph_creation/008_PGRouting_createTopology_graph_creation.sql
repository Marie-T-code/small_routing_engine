-- 06_createTopology.sql
-- Create pgRouting topology from the routes_v1 table
-- Generates source/target columns and the routes_v1_vertices_pgr table

BEGIN;

-- 1) Reset previous topology state
-- Part 1: Clear existing source/target values to avoid silent pgRouting crashes
-- Part 2: Drop previous vertices table if it exists (idempotent execution)
UPDATE public.routes_v1
SET source = NULL,
    target = NULL;

DROP TABLE IF EXISTS public.routes_v1_vertices_pgr CASCADE;

-- 2) Create the routing graph
-- Each row represents an edge, each intersection becomes a vertex
-- A spatial tolerance of 1 meter is used to connect nearby but unconnected endpoints
SELECT pgr_createTopology(
  'public.routes_v1',  -- edge table
  routing_topology_tolerance_m(),                   -- snapping tolerance in meters (depends on the graph SRID; a meter-based SRID is strongly recommended, not a degree-based one)
  'geom',              -- geometry column
  'fid'                -- unique edge identifier
);

-- 3) Quick sanity check
-- Ensure that vertices have been created successfully
SELECT COUNT(*) AS nb_vertices
FROM public.routes_v1_vertices_pgr;

COMMIT;
