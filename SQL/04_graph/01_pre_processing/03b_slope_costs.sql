-- /SQL/04_graph/01_pre_processing/03b_slope_costs.sql
--
-- add slope to the routing weights (cost / reverse_cost) before building the pgRouting topology.
-- Slope-aware costs, derived from cost / reverse_cost (-1 sentinel kept).
-- Linear in elevation gain above a free slope threshold:
--   cost_slope = cost * (1 + k * max(slope_pct - cutoff, 0) / 100)
-- Descents are not discounted (factor >= 1). Unreliable slopes fall back to cost.
-- k and cutoff are calibration parameters (BRouter uphillcost / uphillcutoff as reference).

\echo ''
\echo '>>> START : /SQL/04_graph/01_pre_processing/03b_slope_costs.sql'
\echo ''

\set slope_k 30
\set slope_cutoff 1.5

BEGIN;

\echo '--- setting slope parameters on cost and reverse_cost (already based on length_m)'

UPDATE public.routes_v1
SET cost_slope =
    CASE
        WHEN cost = -1 THEN -1
        WHEN NOT slope_reliable THEN cost
    ELSE cost * (1 + :slope_k * GREATEST(slope_pct - :slope_cutoff, 0) / 100)
    END,

    reverse_cost_slope =
    CASE
        WHEN reverse_cost = -1 THEN -1
        WHEN NOT slope_reliable THEN reverse_cost
    ELSE reverse_cost * (1 + :slope_k * GREATEST(-slope_pct - :slope_cutoff, 0) / 100)
    END;

\echo ' --- post-check slope based directed costs(no NULL, blocked forward and blocked reverse edges, no cost_slope smaller than cost and reverse_cost_slope smaller than reverse_cost, all impacted edges from the update and all impacted edges from calculation) ---'

SELECT
    COUNT(*) - COUNT(cost_slope) AS cost_slope_null,
    COUNT(*) - COUNT(reverse_cost_slope) AS reverse_cost_slope_null,
    COUNT(*) FILTER (WHERE (cost = -1 AND cost_slope <> -1)
                        OR (cost <> -1 AND cost_slope = -1))
    AS blocked_mismatch_forward,
    COUNT(*) FILTER
        (WHERE (reverse_cost = -1 AND reverse_cost_slope <> -1)
            OR (reverse_cost <> -1 AND reverse_cost_slope = -1))
    AS blocked_mismatch_reverse,
    COUNT (*) FILTER(WHERE cost_slope < cost AND cost_slope <> -1)
    AS cost_slope_smaller_than_cost,
    COUNT (*) FILTER(WHERE reverse_cost_slope < reverse_cost
                    AND reverse_cost_slope <> -1)
    AS reverse_slope_smaller_than_reverse_cost,
    COUNT(*) FILTER (WHERE cost_slope > cost) AS penalized_forward,
    COUNT(*) FILTER (WHERE reverse_cost_slope > reverse_cost) AS penalized_reverse,
    COUNT(*) FILTER(WHERE slope_reliable AND ABS(slope_pct) > :slope_cutoff) AS all_edges_with_impacted_slope
FROM public.routes_v1;



COMMIT;

\echo ''
\echo '<<< END   : /SQL/04_graph/01_pre_processing/03b_slope_costs.sql'
\echo ''