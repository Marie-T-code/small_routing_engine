-- SQL/04_graph/01_pre_processing/02a_slope_pct.sql
-- populate altitudes on edges start and end (z_start, z_end) and calculate slope percentage of each edge
-- Precondition: length_m is non NULL and > 0, checked by the guardrail below.
-- It should never fire when 04_edges_cleaning.sql runs first; if it does, check the MASTER order.

\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/02a_slope_pct.sql'
\echo ''

BEGIN;

\echo 'guardrail : if no NULL or <= 0 values in length_m continue'
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.routes_v1
        WHERE length_m IS NULL OR length_m <= 0
    ) THEN
        RAISE EXCEPTION '[GRAPH:LENGTH_M_INVALID] length_m NULL or <= 0 values found' USING ERRCODE = 'P0001';
    END IF;
END
$$;

\echo 'populating z_start and z_end altitude'
UPDATE public.routes_v1 as e
SET z_start = (
        SELECT AVG(ST_Value(d.rast, 1, ST_StartPoint(e.geom), true, 'bilinear'))
        FROM public.dem_nevers AS d
        WHERE d.rast && ST_StartPoint(e.geom)
            AND ST_Intersects(d.rast, ST_StartPoint(e.geom))
    ),
    z_end = (
        SELECT AVG(ST_Value(d.rast, 1, ST_EndPoint(e.geom), true, 'bilinear'))
        FROM public.dem_nevers AS d
        WHERE d.rast && ST_EndPoint(e.geom)
            AND ST_Intersects(d.rast, ST_EndPoint(e.geom))
    );

\echo 'calculating edges slope'
UPDATE public.routes_v1
SET slope_pct = (z_end - z_start) / length_m * 100
WHERE z_start IS NOT NULL
	AND z_end IS NOT NULL;


\echo 'summary : null cells, steep edges, min, max and absolute average slopes (with and without flat data)'
SELECT
    COUNT(*) - COUNT(z_start) AS z_start_null,
    COUNT(*) - COUNT(z_end) AS z_end_null,
    COUNT(*) - COUNT(slope_pct) AS slope_pct_null,
    COUNT(*) FILTER(WHERE ABS(slope_pct) > 15) AS steep_edges,

    ROUND(MIN(slope_pct)::numeric, 2) AS min_slope_pct,
    ROUND(AVG(ABS(slope_pct))::numeric, 2) AS avg_abs_slope,
    ROUND((AVG(ABS(slope_pct)) FILTER (WHERE slope_pct <> 0))::numeric, 2)  AS avg_abs_slope_pct_non_flat,
    ROUND(MAX(slope_pct)::numeric, 2) AS max_slope_pct
FROM public.routes_v1;


COMMIT;


\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/02a_slope_pct.sql'
\echo ''