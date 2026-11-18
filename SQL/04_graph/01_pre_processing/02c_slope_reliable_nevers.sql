-- /SQL/04_graph/01_pre_processing/02c_slope_reliable_nevers.sql
-- Nevers slope-reliability rules: consequences of the territory (engineering structures).
-- Nevers is a fairly flat area: during exploration, most edges at 28% and above lay on
-- engineering structures (bridges, footbridges, lock gates), where the DEM reads the
-- ground or water below the deck.
-- slope_reliable is true by default and never NULL (see DB/init_db/002_create_tables_routes_v1.sql).
-- Rules only ever set it to false (blacklist): an edge that no rule rejects keeps its slope.
-- Cases missed by the exploration therefore stay reliable; they are never silently ignored.

\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/02c_slope_reliable_nevers.sql'
\echo ''

BEGIN;
\echo 'ignore slopes 28% and above on all edges (most explored were engineering structures)'

UPDATE public.routes_v1
SET slope_reliable = false
    WHERE ABS(slope_pct) >= 28
    AND slope_reliable;

\echo '--- Post-check (total_edges, reliable, not_reliable) ---'

SELECT
    COUNT(*) AS total_edges,
    COUNT(*) FILTER(WHERE slope_reliable) AS reliable,
    COUNT(*) FILTER(WHERE NOT slope_reliable) AS not_reliable
FROM public.routes_v1;

COMMIT;

\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/02c_slope_reliable_nevers.sql'
\echo ''

