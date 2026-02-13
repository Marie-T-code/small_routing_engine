-- /SQL/06_MASTERS/00_MASTER_CONFIG.sql

\echo ''
\echo '>>> START : /SQL/06_MASTERS/00_MASTER_CONFIG.sql'
\echo ''

\echo '--- graph_srid, api_srid, topology_tolerance_m, and routing_default_speed ---'
\i /SQL/01_config/routing_constants.sql

\echo ''
\echo '>>> END : /SQL/06_MASTERS/00_MASTER_CONFIG.sql'
\echo ''