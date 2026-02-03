-- 010_edges_check.sql
-- Length sanity checks after graph creation

-- 1) Check how many edges have a null or zero length
SELECT COUNT(*) AS zero_length_edges
FROM public.routes_v1
WHERE length_m IS NULL OR length_m = 0;

-- 2) Global length statistics
SELECT 
  COUNT(*) AS total_edges,
  ROUND(MIN(length_m)::numeric, 2) AS min_length_m,
  ROUND(AVG(length_m)::numeric, 2) AS avg_length_m,
  ROUND(MAX(length_m)::numeric, 2) AS max_length_m
FROM public.routes_v1;

-- 3) Detect very short (potentially parasitic) edges (< 1 m)
SELECT COUNT(*) AS very_short_edges
FROM public.routes_v1
WHERE length_m < 1;

-- 4) Detect highly connected nodes (degree ≥ 9)
SELECT 
    v.id,                           -- vertex id
    COUNT(r.fid) AS connected_edges -- number of edges connected to this vertex
FROM public.routes_v1_vertices_pgr AS v
JOIN public.routes_v1 AS r
  ON v.id IN (r.source, r.target)
GROUP BY v.id
HAVING COUNT(r.fid) >= 9
ORDER BY connected_edges DESC;
