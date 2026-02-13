-- SQL/04_graph/01_pre_processing/04_edges_cleaning.sql
-- removing false edges from the routes_v1(edges) table


\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/04_edges_cleaning.sql'
\echo ''


BEGIN;

-- Remove invalid or degenerate edges (NULL or shorter than 1 meter)
DELETE FROM public.routes_v1
WHERE length_m IS NULL OR length_m < 1;

-- Confirmation
\echo 'Cleaning false edges done.'

COMMIT;


\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/04_edges_cleaning.sql'
\echo ''