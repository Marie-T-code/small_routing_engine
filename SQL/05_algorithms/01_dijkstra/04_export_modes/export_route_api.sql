-- SQL/05_algorithms/01_dijkstra/04_export_modes/export_route_api.sql
--
-- Purpose: Returns a single GeoJSON Feature (API SRID, default: EPSG:4326) with user-facing metrics.
-- Intended for API usage (Flask/psycopg2): no psql meta-commands here.

DROP FUNCTION IF EXISTS export_api_route_feature_api(DOUBLE PRECISION,  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION export_route_api(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION,
  speed_kmh DOUBLE PRECISION DEFAULT 15.0
)
RETURNS JSON
LANGUAGE sql AS $$
  SELECT json_build_object(
    'type', 'Feature',
    'bbox', ST_AsGeoJSON(ST_Envelope(route_geom_api))::json,
    'geometry', ST_AsGeoJSON(route_geom_api)::json,
    'properties', json_build_object(
      'distance_km', total_km,
      'estimated_time_min', estimated_time_min,
      'speed_kmh', export_route_api.speed_kmh
    )
  )::json
  FROM public.route_metrics(lat1, lon1, lat2, lon2, speed_kmh);
$$;