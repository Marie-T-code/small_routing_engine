-- /SQL/YY_data_exploration/steep_slope_small_edges.sql
-- purpose: requests aimed for Qgis use : identifying unusual slope pct on edges
-- exploration goal : identify similar artefacts with aberrant slopes in order to ignore them in cost construction
-- EXPLORATORY ONLY. Not called by any master
-- results in documentation/exploration/steep_slope_small_edges.md


-- 1. identification of steep slopes by length of edges, in relation to the total edges and total steep edges

SELECT
CASE
    WHEN length_m < 5 THEN'1: 0-5 m'
    WHEN length_m < 10 THEN '2: 5-10 m'
    WHEN length_m < 20 THEN '3: 10-20 m'
    WHEN length_m < 40 THEN '4: 20-40 m'
    WHEN length_m >= 40 THEN '5: 40+ m'
    ELSE 'unaccounted for'
END AS length_m_grades,
COUNT(*) AS total_edges,
COUNT(*) FILTER(WHERE abs(slope_pct) > 15)  AS steep_edges,
ROUND ((COUNT(*) FILTER (WHERE abs(slope_pct) > 15) * 100.0) / COUNT(*), 1) AS steep_rate_in_class_pct,
ROUND ((COUNT(*) FILTER (WHERE abs(slope_pct) > 15) * 100.0) / SUM(COUNT(*) FILTER (WHERE abs(slope_pct) > 15)) OVER (), 1) AS share_of_steep_pct
FROM public.routes_v1
GROUP BY length_m_grades
ORDER BY length_m_grades ASC;


-- 2.  identification of small_edges with steep slopes

SELECT fid, geom, length_m, slope_pct
FROM public.routes_v1
WHERE  length_m < 5
AND ABS(slope_pct) > 15;

-- 3. Δz = |slope_pct| × length_m ÷ 100 request

SELECT
ROUND((abs(slope_pct) * length_m/100)::numeric, 2) as dz_m,
COUNT(*) AS number_edges
FROM public.routes_v1
WHERE  length_m < 5
AND ABS(slope_pct) > 15
GROUP BY dz_m
ORDER BY dz_m;

-- - 4. distribution of steep small edges by slope grade (tests H2)

SELECT
CASE
    WHEN ABS(slope_pct) <= 20 THEN '1: 15-20 %'
    WHEN ABS(slope_pct) <= 28 THEN '2: 20-28 %'
    ELSE '3: 28+ %'
END AS slopes_grades,
COUNT(*) AS number_edges
FROM public.routes_v1
WHERE  length_m < 5
AND ABS(slope_pct) > 15
GROUP BY slopes_grades
ORDER BY slopes_grades;

-- 5. identifying highway types with very steep slopes

SELECT highway,
COUNT(*) AS small_edge_cases
FROM public.routes_v1
WHERE length_m <5
AND ABS(slope_pct) >28
GROUP BY highway
ORDER BY highway ASC;

-- 6. looking for cyclable highway types with very steep slopes (example : primary)

SELECT fid, geom, length_m, slope_pct
FROM public.routes_v1
WHERE  length_m < 5
AND ABS(slope_pct) > 28
AND highway IN ('primary', 'secondary', 'tertiary');

-- 7. share of each highway type in the whole graph
SELECT highway,
COUNT(*) AS edges,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM public.routes_v1
GROUP BY highway
ORDER BY edges DESC;
