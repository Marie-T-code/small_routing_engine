\pset tuples_only on
\pset format unaligned
\o /exports/vertices_analyze.geojson
SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', json_agg(
    json_build_object(
      'type', 'Feature',
      'geometry', ST_AsGeoJSON(ST_Transform(sub.the_geom, 4326))::json,
      'properties', json_build_object(
        'id', sub.id,
        'chk', sub.chk
      )
    )
  )
)
FROM(
  SELECT v.the_geom, v.id, v.chk
  FROM public.routes_v1_vertices_pgr AS v
  WHERE v.chk <> 0  -- on garde uniquement les nœuds isolés ou problématiques
) AS sub;
\o

