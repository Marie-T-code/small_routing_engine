-- 001_init_extensions.sql
-- Purpose: Install required extensions for PostGIS + pgRouting

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;

COMMIT;