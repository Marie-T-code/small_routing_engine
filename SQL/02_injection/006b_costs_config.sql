-- 006b_costs_config
-- ---------------------------------------------------------------------
-- Here is where you customize your costs and reverse costs
-- this is necessary before creating the graph
-- for this prototype, the only parameter for cost calculation are the edge's length in meters 
-- ---------------------------------------------------------------------
-- 006b_costs_config.sql
-- ---------------------------------------------------------------------
-- Configure routing weights (cost / reverse_cost) before building the pgRouting topology.
-- For this prototype, costs are simply the edge length in meters (length_m).
-- ---------------------------------------------------------------------

BEGIN;

\echo '--- Setting cost and reverse_cost from length_m (meters) ---'

-- Set cost and reverse_cost to the edge length
-- (These values are used as weights by Dijkstra / bdDijkstra)
UPDATE public.routes_v1
SET cost = length_m,
    reverse_cost = length_m
WHERE length_m IS NOT NULL
  AND (cost IS NULL OR reverse_cost IS NULL);

\echo '--- Post-check (cost stats, based on length_m) ---'
SELECT
  COUNT(*) AS total_rows,
  AVG(length_m) AS avg_m,
  MIN(length_m) AS min_m,
  MAX(length_m) AS max_m
FROM public.routes_v1;

COMMIT;

\echo '✅ Costs configured: cost and reverse_cost are now set to length_m (meters).'
