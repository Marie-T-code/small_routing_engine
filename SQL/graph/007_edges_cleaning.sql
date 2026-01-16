BEGIN;

-- eRemove invalid or degenerate edges (NULL or shorter than 1 meter)
DELETE FROM public.routes_v1
WHERE length_m IS NULL OR length_m < 1;

-- Confirmation
\echo 'Cleaning false edges done.'

COMMIT;
