-- export/export_api_route_feature_4326_psql.sql
-- psql-only helper: writes the API GeoJSON Feature to a file.
-- Usage (psql): \i /SQL/algorithms/dijkstra/export/export_api_route_feature_4326_psql.sql
-- Output: /exports/api_route_feature_4326.geojson

\pset tuples_only on
\pset format unaligned
\pset pager off

-- change these values for your tests
\set lat1 46.85674
\set lon1 2.99661
\set lat2 46.86025
\set lon2 3.16577
\set speed_kmh 15.0

\o /exports/api_route_feature_4326.geojson

SELECT export_api_route_feature_4326(:lat1, :lon1, :lat2, :lon2, :speed_kmh)::text;

\o
\pset pager on
