-- SQL/05_algorithms/01_dijkstra/xx_debug//export_route_segments.sql
--
-- Purpose: Export a debug GeoJSON FeatureCollection (one Feature per route segment).
-- CRS: graph SRID (routing_graph_srid(), currently EPSG:2154), intended for GIS/QGIS debugging
-- Usage (psql): \i debug/export_route_segments_.sql

\pset tuples_only on
\pset format unaligned
\pset pager off

-- change these values for testing
\set lat1 46.85674
\set lon1 2.99661
\set lat2 46.86025
\set lon2 3.16577


\o /exports/debug_route_segments.geojson

SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', json_agg(
    json_build_object(
      'type', 'Feature',
      'geometry', ST_AsGeoJSON(geom)::json,
      'properties', json_build_object(
        'seq', seq,
        'edge_id', edge_id,
        'cost', cost,
        'agg_cost', agg_cost,
        'length_m', length_m
      )
    )
    ORDER BY seq
  )
)::text
FROM dijkstra_snap_debug(:lat1, :lon1, :lat2, :lon2);

\o
\pset pager on
