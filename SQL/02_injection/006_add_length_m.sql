-- 006_add_length_m.sql
-- ---------------------------------------------------------------------
-- Compute edge lengths in meters (length_m) for each edge of the future graph.
--
-- Implementation choice (prototype-friendly):
-- - Always transform to the graph_SRID before measuring length.
-- - This guarantees meter-based lengths even if geom is currently in api_SRID like 4326.
-- ---------------------------------------------------------------------

BEGIN;

SELECT routing_graph_srid() AS graph_srid \gset;

\echo '--- Computing edge lengths (length_m, meters; using ST_Transform -> EPSG:' :graph_srid ') ---'

-- Preliminary check
SELECT
  COUNT(*) AS total_rows,
  COUNT(length_m) AS already_filled,
  COUNT(*) FILTER (WHERE length_m IS NULL) AS to_compute
FROM public.routes_v1;

-- Compute lengths in meters (transform to Lambert-93 if needed)
UPDATE public.routes_v1
SET length_m = ST_Length(
  CASE
    WHEN ST_SRID(geom) = routing_graph_srid() THEN geom
    ELSE ST_Transform(geom, routing_graph_srid())
  END
)
WHERE length_m IS NULL;

\echo '--- Post-check (length_m stats) ---'
SELECT
  COUNT(*) AS total_rows,
  COUNT(length_m) AS filled_length_m,
  MIN(length_m) AS min_m,
  AVG(length_m) AS avg_m,
  MAX(length_m) AS max_m
FROM public.routes_v1;

COMMIT;

\echo '✅ length_m computed successfully (meters, EPSG:' :graph_srid ').'