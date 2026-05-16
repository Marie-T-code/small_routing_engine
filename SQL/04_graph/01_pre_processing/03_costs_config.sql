
-- SQL/04_graph/01_pre_processing/03_costs_config.sql
-- ---------------------------------------------------------------------
-- Configure routing weights (cost / reverse_cost) before building the pgRouting topology.
-- For this prototype, costs are simply the edge length in meters (length_m).
-- ---------------------------------------------------------------------




BEGIN;

\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/03_costs_config.sql'
\echo ''

\echo '--- Setting cost and reverse_cost from length_m (meters) ---'

-- Set cost and reverse_cost to the edge length
-- (These values are used as weights by Dijkstra)
UPDATE public.routes_v1
SET cost =
  CASE WHEN oneway = '-1' THEN -1
  ELSE length_m
  END,
    reverse_cost = 
  CASE WHEN oneway = 'yes' THEN -1 
  ELSE length_m
  END
WHERE length_m IS NOT NULL;

\echo '--- Post-check (cost stats, based on length_m) ---'
SELECT
  COUNT(*) AS total_rows,
  AVG(length_m) AS avg_m,
  MIN(length_m) AS min_m,
  MAX(length_m) AS max_m
FROM public.routes_v1;

\echo '✅ Costs configured: cost and reverse_cost are now set to length_m (meters).'

\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/03_costs_config.sql'
\echo ''

COMMIT;


