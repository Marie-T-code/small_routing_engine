BEGIN;

\echo '--- Suppression de la colonne comp (inutile pour le graphe minimal) ---'
ALTER TABLE routes_v1 DROP COLUMN IF EXISTS comp;

COMMIT;