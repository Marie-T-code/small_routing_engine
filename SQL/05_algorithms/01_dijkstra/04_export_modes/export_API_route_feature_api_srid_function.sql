-- SQL/05_algorithms/01_dijkstra/04_export_modes/export_API_route_feature_api_srid_function.sql
--
-- Purpose: Returns a single GeoJSON Feature (API SRID, default: EPSG:4326) with user-facing metrics.
-- Intended for API usage (Flask/psycopg2): no psql meta-commands here.

CREATE OR REPLACE FUNCTION export_api_route_feature_api(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION,
  speed_kmh DOUBLE PRECISION DEFAULT 15.0
)
RETURNS JSON
LANGUAGE sql AS $$
  SELECT json_build_object(
    'type', 'Feature',
    'geometry', ST_AsGeoJSON(geom_api)::json,
    'properties', json_build_object(
      'distance_km', total_km,
      'estimated_time_min', estimated_time_min,
      'speed_kmh', export_api_route_feature_api.speed_kmh
    )
  )::json
  FROM public.route_metrics_snap(lat1, lon1, lat2, lon2, speed_kmh);
$$;