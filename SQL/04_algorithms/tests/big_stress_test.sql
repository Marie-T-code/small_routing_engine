-- 019_big_stress_test
-- selection of 12 points : all around the graph and ending up in the center of the town.

\pset format unaligned
\pset tuples_only on
\o /exports/graph_tour.geojson

WITH 
a AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(46.85674, 2.99661),  -- south-west
    snap_to_nearest_node(46.86025,3.16577),  -- Magny-Cours south
    true
)),
b AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(46.86025,3.16577),  --- Magny-Cours south
    snap_to_nearest_node(46.92252,3.269513),  -- Imphy south east
    true
)),
c AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(46.92252,3.269513),  -- Imphy south east
    snap_to_nearest_node(47.004229,3.354311),  -- D978 east
    true
)),
d AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(47.004229,3.354311),  -- D978 east
    snap_to_nearest_node(47.07342,3.32531),  -- Ourouer North east
    true
)),
e AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(47.07342,3.32531),  -- Ourouer North east
    snap_to_nearest_node(47.1189,3.26215), -- ferme de Chaillant North
    true
)),
f AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(47.1189,3.26215), -- ferme de Chaillant North
    snap_to_nearest_node(47.0873,3.19756), -- Guerigny North
    true
)),
g AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(47.0873,3.19756), -- Guerigny North
    snap_to_nearest_node(47.11117,3.10276), -- Le Chazeau north north-west
    true
)),
h AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(47.11117,3.10276), -- Le Chazeau north north-west
    snap_to_nearest_node(47.06782,3.01187), -- Marseilles-les-Aubigny north west
    true
)),
i AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(47.06782,3.01187), -- Marseilles-les-Aubigny north west
    snap_to_nearest_node(46.97645,2.96684), -- Le Chautry West
    true
)),
j AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(46.97645,2.96684),-- Le Chautry West
    snap_to_nearest_node(46.85674, 2.99661),  -- south-west departure point
    true
)),
k AS (SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM routing_edges',
    snap_to_nearest_node(46.85674, 2.99661),  -- south-west departure point
    snap_to_nearest_node(46.987066,3.15119), -- end of the line : railway station od Nevers
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
    UNION ALL
    SELECT * FROM e
    UNION ALL
    SELECT * FROM f
    UNION ALL
    SELECT * FROM g
    UNION ALL
    SELECT * FROM h
    UNION ALL
    SELECT * FROM i
    UNION ALL
    SELECT * FROM j
    UNION ALL
    SELECT * FROM k
)
SELECT json_build_object(
    'type','FeatureCollection',
    'features', json_agg(
        json_build_object(
            'type','Feature',
            'geometry', ST_AsGeoJSON(ST_Transform(r.geom,routing_api_srid()))::json,
            'properties', json_build_object(
                'edge', d.edge,
                'cost', d.cost,
                'seq', d.seq
            )
        )
    )
)
FROM tour d
JOIN routing_edges r ON d.edge = r.id
WHERE d.edge <> -1;

\o
