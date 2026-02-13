-- SQL/04_graph/01_pre_processing/02_add_length_m.sql
-- computes and checks the edges' length in meters

\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/02_add_length_m.sql'
\echo ''


BEGIN;

\echo '--- Computing edge lengths (length_m, meters; using ST_Transform -> graph SRID) ---'

-- Preliminary check
SELECT
  COUNT(*) AS total_rows,
  COUNT(length_m) AS already_filled,
  COUNT(*) FILTER (WHERE length_m IS NULL) AS to_compute
FROM public.routes_v1;

-- Compute lengths in meters (always transform to graph SRID)
UPDATE public.routes_v1
SET length_m = ST_Length(
  ST_Transform(
    ST_SetSRID(geom, routing_api_srid()),
    routing_graph_srid()
  )
)
WHERE length_m IS NULL
  AND geom IS NOT NULL;

\echo '--- Post-check (length_m stats) ---'
SELECT
  COUNT(*) AS total_rows,
  COUNT(length_m) AS filled_length_m,
  MIN(length_m) AS min_m,
  AVG(length_m) AS avg_m,
  MAX(length_m) AS max_m
FROM public.routes_v1;

COMMIT;

\echo '✅ length_m computed successfully (meters).'

\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/02_add_length_m.sql'
\echo ''