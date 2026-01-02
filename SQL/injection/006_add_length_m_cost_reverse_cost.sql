-- 006_add_length_m_cost_reverse_cost
-- ---------------------------------------------------------------------
-- Calcul de la longueur en mètres pour chaque arête du réseau routier
-- remplir cost et reverse_cost en prenant uniquement en paramètre la longueur des aretes en mètres
-- Nécessaire avant la création du graphe pgRouting
-- ---------------------------------------------------------------------

BEGIN;

\echo '--- Calcul des longueurs (length_m) ---'

-- Vérification préliminaire (nombre de lignes concernées)
SELECT COUNT(*) AS total_lignes,
       COUNT(length_m) AS deja_remplies,
       COUNT(*) FILTER (WHERE length_m IS NULL) AS a_calculer
FROM public.routes_v1;

-- Calcul des longueurs en mètres (Lambert 93)
UPDATE public.routes_v1
SET length_m = ST_Length(geom)
WHERE length_m IS NULL;

-- Définir cost et reverse_cost comme la longueur
-- (Ces valeurs servent de poids dans les calculs d'itinéraires Dijkstra simples)
UPDATE routes_v1
SET cost = length_m,
    reverse_cost = length_m
WHERE cost IS NULL OR reverse_cost IS NULL;

\echo '--- Vérification post-calcul ---'
SELECT COUNT(*) AS total, 
       AVG(length_m) AS moyenne_m, 
       MIN(length_m) AS min_m, 
       MAX(length_m) AS max_m
FROM public.routes_v1;

COMMIT;

\echo '✅ Longueurs calculées avec succès, cost et reverse_cost remplis => longueur en mètres simple.'