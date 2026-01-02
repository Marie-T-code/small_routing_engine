-- 05_createTopology.sql
-- Crée la topologie pgRouting à partir de la table routes_v1
-- Génére les colonnes source/target et la table routes_v1_vertices_pgr

BEGIN;

-- 1️⃣ Nettoyage de la topologie précédente si elle existe
-- (évite les doublons quand on rejoue le script)
DROP TABLE IF EXISTS public.routes_v1_vertices_pgr CASCADE;

-- 2️⃣ Création du graphe : chaque ligne = arête, chaque intersection = sommet
SELECT pgr_createTopology(
  'public.routes_v1',  -- table des lignes
  1,              -- tolérance spatiale (1m), la tolérance spatiale connectera des sommet à moins d'un mètre l'un de l'autre non connectés
  'geom',              -- colonne géométrique
  'fid'                -- identifiant unique des arêtes
);

-- 3️⃣ Vérification rapide
SELECT COUNT(*) AS nb_vertices FROM public.routes_v1_vertices_pgr;

COMMIT;