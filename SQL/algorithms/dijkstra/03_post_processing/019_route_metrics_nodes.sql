-- 020_route_metrics_nodes.sql
-- Post-processing: from start/end nodes -> route LINESTRING + distance + estimated time
-- Note: printing large geometries as WKT in psql can trigger the pager / appear to “hang”. Prefer ST_NPoints, ST_Envelope, or file export for debugging. A streaming GeoJSON export can be added if a detailed per-segment output is needed.
-- if nothing comes up in the terminal check : 
-- SELECT length(ST_AsText(geom_4326)) AS wkt_chars
-- FROM route_metrics_nodes(<start_node>, <end_node>, 15.0);


CREATE OR REPLACE FUNCTION route_metrics_nodes(
  start_node BIGINT,
  end_node   BIGINT,
  speed_kmh  DOUBLE PRECISION DEFAULT 15.0
)
RETURNS TABLE (
  total_m            DOUBLE PRECISION,
  total_km           DOUBLE PRECISION,
  estimated_time_min DOUBLE PRECISION,
  geom_2154          geometry(LineString, 2154),
  geom_4326          geometry(LineString, 4326)
)
LANGUAGE sql AS $$
WITH segs AS (
  SELECT seq, geom, length_m
  FROM dijkstra_only(start_node, end_node)
  ORDER BY seq
),
pts AS (
  SELECT
    array_prepend(
      (SELECT ST_StartPoint(geom) FROM segs ORDER BY seq LIMIT 1),
      array_agg(ST_EndPoint(geom) ORDER BY seq)
    ) AS arr
  FROM segs
),
line AS (
  SELECT ST_MakeLine(arr) AS geom_2154
  FROM pts
),
tot AS (
  SELECT COALESCE(SUM(length_m), 0)::double precision AS total_m
  FROM segs
)
SELECT
  tot.total_m,
  (tot.total_m / 1000.0)::double precision AS total_km,
  CASE
    WHEN speed_kmh IS NULL OR speed_kmh <= 0 THEN NULL
    ELSE ((tot.total_m / 1000.0) / speed_kmh * 60.0)::double precision
  END AS estimated_time_min,
  line.geom_2154,
  ST_Transform(line.geom_2154, 4326) AS geom_4326
FROM tot
CROSS JOIN line;
$$;
