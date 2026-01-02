-- 017_dijkstra_snap.sql
-- Calcule un itinéraire entre deux points géographiques (lat/lon)
-- en utilisant le snapping vers les nœuds du graphe
-- Version optimisée (streaming, non bloquante)

CREATE OR REPLACE FUNCTION dijkstra_snap(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
)
RETURNS SETOF JSON LANGUAGE plpgsql AS $$
DECLARE
  s BIGINT;
  t BIGINT;
  rec RECORD;
BEGIN
  s := snap_to_nearest_node(lat1, lon1);
  t := snap_to_nearest_node(lat2, lon2);

  FOR rec IN
    SELECT
      json_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform(r.geom,4326))::json,
        'properties', json_build_object(
          'edge', d.edge,
          'cost', d.cost,
          'seq', d.seq
        )
      ) AS feature
    FROM pgr_dijkstra(
      'SELECT fid AS id, source, target, cost, reverse_cost FROM routes_v1',
      s, t, true
    ) AS d
    JOIN routes_v1 AS r
      ON d.edge = r.fid
    WHERE d.edge <> -1
    ORDER BY d.seq
  LOOP
    RETURN NEXT rec.feature;
  END LOOP;

  RETURN;
END;
$$;
