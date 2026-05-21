-- SQL/04_graph/02_graph_creation/01_PGRouting_createTopology_graph_creation.sql
-- Create pgRouting topology from the routes_v1 table
-- Generates source/target columns and the routes_v1_vertices_pgr table

\echo ''
\echo '>>> START : /SQL/04_graph/02_graph_creation/01_PGRouting_createTopology_graph_creation.sql'
\echo ''




  \echo 'building graph can take some time, please wait....'
  
  BEGIN;

  SELECT assert_graph_preconditions();


  -- 1) Drops the vertices table to ensure pgr_createTopology() function's indepotency

  DROP TABLE IF EXISTS public.routes_v1_vertices_pgr CASCADE;

  -- 2) Create the routing graph
  -- Each row represents an edge, each intersection becomes a vertex
  -- A spatial tolerance of 1 meter is used to connect nearby but unconnected endpoints
  SET client_min_messages = WARNING;
  SELECT pgr_createTopology(
    'public.routes_v1',  -- edge table
    routing_topology_tolerance_m(),                   -- snapping tolerance in meters (depends on the graph SRID; a meter-based SRID is strongly recommended, not a degree-based one)
    'geom',              -- geometry column
    'fid'                -- unique edge identifier
  );

  COMMIT; 
  -- 3) Quick sanity check
  -- Ensure that vertices have been created successfully
  SELECT COUNT(*) AS nb_vertices
  FROM public.routes_v1_vertices_pgr;


\echo ''
\echo '>>> END : /SQL/04_graph/02_graph_creation/01_PGRouting_createTopology_graph_creation.sql'
\echo ''