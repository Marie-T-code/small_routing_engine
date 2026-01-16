-- Vérification des longueurs après la création du graphe

-- 1️⃣ Vérifie combien de lignes ont une longueur nulle ou manquante
SELECT COUNT(*) AS nb_zero_length
FROM public.routes_v1
WHERE length_m IS NULL OR length_m = 0;

-- 2️⃣ Petit contrôle global
SELECT 
  COUNT(*) AS total,
  ROUND(MIN(length_m)::numeric, 2) AS min_len,
  ROUND(AVG(length_m)::numeric, 2) AS avg_len,
  ROUND(MAX(length_m)::numeric, 2) AS max_len
FROM public.routes_v1;

-- 3️⃣ Repérer les mini lignes parasites (< 1 m)
SELECT COUNT(*) AS nb_trop_courtes
FROM public.routes_v1
WHERE length_m < 1;

-- 4️⃣ Détection des nœuds à forte connectivité (≥ 9 arêtes)
SELECT 
    v.id,  -- identifiant du nœud
    COUNT(r.fid) AS nb_arcs_connectes -- nombre d’arêtes reliées à ce nœud
FROM public.routes_v1_vertices_pgr AS v
JOIN public.routes_v1 AS r
  ON v.id = r.source OR v.id = r.target
GROUP BY v.id
HAVING COUNT(r.fid) >= 9
ORDER BY nb_arcs_connectes DESC;
