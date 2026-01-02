\pset tuples_only on
\pset format unaligned
\o /exports/trajet_periph_centre.geojson
SELECT json_build_object(
    'type', 'FeatureCollection', 
    'features', json_agg(
        json_build_object(
            'type', 'Feature', 
            'geometry', ST_AsGeoJSON(ST_Transform(sub.geom, 4326))::json, 
            'properties', json_build_object(
                'edge', sub.edge, 
                'cost', sub.cost, 
                'seq', sub.seq
            )
        )
    )
) 
FROM (
    SELECT d.seq, d.edge, d.cost, r.geom
    FROM pgr_dijkstra(
        'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1', 
        49828, 4896, true
    ) AS d
    JOIN routes_v1 AS r
        ON d.edge = r.fid
    WHERE d.edge <> -1
) AS sub;
\o