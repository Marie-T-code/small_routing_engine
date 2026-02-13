-- /SQL/06_MASTERS/91_MASTER_ALL_DEBUG.sql
-- exports as text the pipeline process to track potential errors


\pset pager off
\timing on
\set ON_ERROR_STOP on


\echo '=========================================='
\echo ' MASTER ALL DEBUG START'
\echo '=========================================='


\timing on
\set ON_ERROR_STOP on

\echo ''
\echo '--- CONFIG ---'
\i /SQL/06_MASTERS/00_MASTER_CONFIG.sql

\echo ''
\echo '--- GRAPH ---'
\i /SQL/06_MASTERS/10_MASTER_GRAPH.sql

\echo ''
\echo '--- ROUTING ---'
\i /SQL/06_MASTERS/20_MASTER_ROUTING_FUNCTIONS.sql

\echo ''
\echo '=========================================='
\echo ' MASTER ALL DEBUG DONE'
\echo '=========================================='

