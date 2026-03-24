-- SQL/04_graph/01_pre_processing/01_clean_table_structure.sql
-- Purpose: Clean the table structure after ogr2ogr import
-- ogr2ogr imports the full GeoPackage schema (-addfields),
-- this script removes unused columns to keep a minimal routing table.

\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/01_clean_table_structure.sql'
\echo ''

BEGIN;

\echo '--- Dropping column comp (not required for the minimal routing graph) ---'
ALTER TABLE public.routes_v1
DROP COLUMN IF EXISTS comp;

COMMIT;

\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/01_clean_table_structure.sql'
\echo ''