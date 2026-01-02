BEGIN;

-- Suppression des arêtes nulles ou sans longueur
DELETE FROM public.routes_v1
WHERE length_m IS NULL OR length_m = 0;

-- Suppression des arêtes parasites (< 1 m)
DELETE FROM public.routes_v1
WHERE length_m < 1;

-- Confirmation (facultative)
\echo 'Nettoyage terminé.'

COMMIT;
