-- /SQL/02_views/routing_edges.sql
-- Purpose:
--   Provide a stable, canonical view of routing edges for all routing algorithms.
--
-- This view abstracts the physical edges table (public.routes_v1) and exposes
-- a consistent schema expected by pgRouting-based algorithms.
--
-- Usage:
-- - All routing and routing-dependent functions MUST query this view
--   instead of accessing the underlying table directly.
-- - The underlying table may change (versioning, imports, schema),
--   while this view preserves a stable internal contract.
--
-- Notes:
-- - The graph topology (source/target) must be created beforehand
--   using pgr_createTopology.

\echo ''
\echo '>>> START : /SQL/02_views/routing_edges.sql'
\echo ''

CREATE OR REPLACE VIEW routing_edges AS
SELECT
  fid AS id,
  source,
  target,
  cost,
  reverse_cost,
  geom,
  length_m
FROM public.routes_v1;


\echo ''
\echo '<<< END   : /SQL/02_views/routing_edges.sql'
\echo ''