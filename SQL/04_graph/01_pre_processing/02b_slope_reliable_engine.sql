-- SQL/04_graph/01_pre_processing/02b_slope_reliable_engine.sql
-- Engine slope-reliability rules: consequences of the DEM (5 m pixels, Int16).
-- slope_reliable is true by default and never NULL (see DB/init_db/002_create_tables_routes_v1.sql).
-- Rules only ever set it to false (blacklist): an edge that no rule rejects keeps its slope.
-- Cases missed by the exploration therefore stay reliable; they are never silently ignored.


\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/02b_slope_reliable_engine.sql'
\echo ''

BEGIN;
\echo 'ignore slopes on edges under 5m long, Int16 rounding fakes steep slopes on short edges'

UPDATE public.routes_v1
SET slope_reliable = false
WHERE length_m < 5;

\echo '--- Post-check (total_edges, reliable, not_reliable) ---'

SELECT
    COUNT(*) AS total_edges,
    COUNT(*) FILTER(WHERE slope_reliable) AS reliable,
    COUNT(*) FILTER(WHERE NOT slope_reliable) AS not_reliable
FROM public.routes_v1;

COMMIT;

\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/02b_slope_reliable_engine.sql'
\echo ''