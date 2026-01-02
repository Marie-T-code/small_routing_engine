\pset tuples_only on
\pset format unaligned
\o /exports/multi_points_periph_centre.geojson

WITH maison_ecole AS (
    SELECT * FROM pgr_dijkstra(
        'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
        49828, 20892, true
    )
),
ecole_travail AS(
    SELECT * FROM pgr_dijkstra(
        'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
        20892, 4896, true
    )
), 
TRAJET AS(
    SELECT * FROM maison_ecole
    UNION ALL
    SELECT * FROM ecole_travail
)
SELECT json_build_object(
    'type', 'FeatureCollection',
    'features', json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', ST_AsGeoJSON(ST_Transform(r.geom, 4326))::json,
            'properties', json_build_object(
                'edge', d.edge,
                'cost', d.cost,
                'seq', d.seq
            )
        )
    )
)
FROM trajet d
JOIN routes_v1 r
  ON d.edge = r.fid
WHERE d.edge <> -1;

\o 