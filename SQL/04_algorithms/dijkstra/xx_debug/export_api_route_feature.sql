-- export/export_api_route_feature.sql
-- Purpose: psql-only helper to write the API GeoJSON Feature to a file.
-- Usage (psql): \i /SQL/algorithms/dijkstra/export/export_api_route_feature.sql
-- Output file: /exports/api_route_feature_webSRID.geojson


\pset tuples_only on
\pset format unaligned
\pset pager off

-- change these values for your tests
\set lat1 46.85674
\set lon1 2.99661
\set lat2 46.86025
\set lon2 3.16577

-- fetch default speed from DB
SELECT routing_default_speed_kmh() AS speed_kmh \gset

\o /exports/export_api_route_feature.geojson

SELECT export_api_route_feature_api(
  :lat1, :lon1, :lat2, :lon2, :speed_kmh
)::text;

\o
\pset pager on
