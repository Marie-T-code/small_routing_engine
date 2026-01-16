-- 018_stress_test_dijkstra_snap.sql
-- Test de performance et de stabilité de la fonction dijkstra_snap
-- Objectif : simuler un itinéraire multipoints bouclant la ville de Nevers

\pset format unaligned
\pset tuples_only on
\o /exports/tour_de_ville.geojson

WITH 
a AS (SELECT * FROM pgr_dijkstra(
    'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
    snap_to_nearest_node(47.0305,3.1250),  -- Nord-Ouest
    snap_to_nearest_node(47.0300,3.2000),  -- Nord-Est
    true
)),
b AS (SELECT * FROM pgr_dijkstra(
    'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
    snap_to_nearest_node(47.0300,3.2000),  -- Nord-Est
    snap_to_nearest_node(46.9650,3.2050),  -- Sud-Est
    true
)),
c AS (SELECT * FROM pgr_dijkstra(
    'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
    snap_to_nearest_node(46.9650,3.2050),  -- Sud-Est
    snap_to_nearest_node(46.9650,3.1250),  -- Sud-Ouest
    true
)),
d AS (SELECT * FROM pgr_dijkstra(
    'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
    snap_to_nearest_node(46.9650,3.1250),  -- Sud-Ouest
    snap_to_nearest_node(47.0305,3.1250),  -- retour Nord-Ouest
    true
)),
tour AS (
    SELECT * FROM a
    UNION ALL
    SELECT * FROM b
    UNION ALL
    SELECT * FROM c
    UNION ALL
    SELECT * FROM d
)
SELECT json_build_object(
    'type','FeatureCollection',
    'features', json_agg(
        json_build_object(
            'type','Feature',
            'geometry', ST_AsGeoJSON(ST_Transform(r.geom,4326))::json,
            'properties', json_build_object(
                'edge', d.edge,
                'cost', d.cost,
                'seq', d.seq
            )
        )
    )
)
FROM tour d
JOIN routes_v1 r ON d.edge = r.fid
WHERE d.edge <> -1;

\o
