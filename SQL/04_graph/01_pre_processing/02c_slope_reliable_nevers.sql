-- /SQL/04_graph/01_pre_processing/02c_slope_reliable_nevers.sql
-- Nevers slope-reliability rules: consequences of the territory (engineering structures).
-- R2. Nevers is a fairly flat area: during exploration, most edges at 28% and above lay on
-- engineering structures (bridges, footbridges, lock gates), where the DEM reads the
-- ground or water below the deck.
-- Roads (p/s/t): highway = primary, secondary or tertiary. Other types are not concerned
-- (e.g. unclassified, which in the Nevers area mostly tags small village roads).
-- R3. Roads (p/s/t) have 15% and above slopes ignored on 5 to 20 meters edges.
-- R4. Roads (p/s/t) have 20% and above slopes ignored on edges of 20 m and more.


-- slope_reliable is true by default and never NULL (see DB/init_db/002_create_tables_routes_v1.sql).
-- Rules only ever set it to false (blacklist): an edge that no rule rejects keeps its slope.
-- Cases missed by the exploration therefore stay reliable; they are never silently ignored.

\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/02c_slope_reliable_nevers.sql'
\echo ''

BEGIN;
\echo 'R2 ignore slopes 28% and above on all edges (most explored were engineering structures)'

UPDATE public.routes_v1
SET slope_reliable = FALSE
WHERE ABS(slope_pct) >= 28
    AND slope_reliable;

\echo '--- Post-check R2 (total_edges, reliable, not_reliable) ---'

SELECT
    COUNT(*) AS total_edges,
    COUNT(*) FILTER(WHERE slope_reliable) AS reliable,
    COUNT(*) FILTER(WHERE NOT slope_reliable) AS not_reliable
FROM public.routes_v1;

\echo 'R3 ignore slopes 15% and above on p/s/t roads of 5 to 20 m'

UPDATE public.routes_v1
SET slope_reliable = FALSE
WHERE length_m >= 5
    AND length_m < 20
    AND highway IN ('primary', 'secondary', 'tertiary')
    AND ABS(slope_pct) >= 15
    AND slope_reliable;

\echo '--- Post-check R3 (total_edges, reliable, not_reliable) ---'

SELECT
    COUNT(*) AS total_edges,
    COUNT(*) FILTER(WHERE slope_reliable) AS reliable,
    COUNT(*) FILTER(WHERE NOT slope_reliable) AS not_reliable
FROM public.routes_v1;

\echo 'R4 ignore slopes 20% and above on p/s/t roads of 20 m long and more'

UPDATE public.routes_v1
SET slope_reliable = FALSE
WHERE length_m >= 20
    AND highway IN ('primary', 'secondary', 'tertiary')
    AND ABS(slope_pct) >= 20
    AND slope_reliable;

\echo '--- Post-check R4 (total_edges, reliable, not_reliable) ---'

SELECT
    COUNT(*) AS total_edges,
    COUNT(*) FILTER(WHERE slope_reliable) AS reliable,
    COUNT(*) FILTER(WHERE NOT slope_reliable) AS not_reliable
FROM public.routes_v1;

COMMIT;

\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/02c_slope_reliable_nevers.sql'
\echo ''
