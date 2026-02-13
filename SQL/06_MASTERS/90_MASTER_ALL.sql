-- SQL/06_MASTERS/90_MASTER_ALL.sql
--
-- Purpose: Run the full database setup in the correct order.
-- This master should only orchestrate other masters (no business SQL here).

\echo '========================================'
\echo ' MASTER ALL - START'
\echo '========================================'

\echo ''
\echo '--- [1/3] CONFIG ---'
\i /SQL/06_MASTERS/00_MASTER_CONFIG.sql

\echo ''
\echo '--- [2/3] GRAPH BUILD ---'
\i /SQL/06_MASTERS/10_MASTER_GRAPH.sql

\echo ''
\echo '--- [3/3] ROUTING FUNCTIONS ---'
\i /SQL/06_MASTERS/20_MASTER_ROUTING_FUNCTIONS.sql

\echo ''
\echo '========================================'
\echo ' MASTER ALL - DONE'
\echo '========================================'
