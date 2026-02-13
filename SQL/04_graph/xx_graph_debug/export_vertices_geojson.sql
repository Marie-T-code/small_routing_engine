-- SQL/04_graph/XX_graph_debug/export_vertices_geojson.sql
-- Export problematic vertices detected by pgr_analyzeGraph as GeoJSON (API_SRID)
-- Only vertices with chk <> 0 are exported (isolated, terminal, or anomalous nodes)

\pset tuples_only on
\pset format unaligned

\o /exports/vertices_analyze.geojson

SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', json_agg(
    json_build_object(
      'type', 'Feature',
      'geometry', ST_AsGeoJSON(
        ST_Transform(sub.the_geom, routing_api_srid())
      )::json,
      'properties', json_build_object(
        'id', sub.id,
        'chk', sub.chk
      )
    )
  )
)
FROM (
  SELECT
    v.the_geom,
    v.id,
    v.chk
  FROM public.routing_vertices AS v
  WHERE v.chk <> 0  -- keep isolated and problematic nodes only
) AS sub;

\o
