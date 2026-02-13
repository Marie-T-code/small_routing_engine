-- ==========================================================
--  MASTER_DIJKSTRA.sql  |  Pipeline complet Nevers à vélo V1
-- ==========================================================
-- Exécuter avec :
--
-- docker exec -it nevers_postgis psql -U postgres -d nevers -f /SQL/MASTER/MASTER_DIJKSTRA.sql
--
--  
-- ==========================================================
SET client_min_messages = NOTICE;
SET log_min_messages = NOTICE;
\timing
\o /exports/log_master.txt


SELECT now() AS debut_pipeline;

\echo '--- 0️⃣ Calcul des longueurs en mètres ---'
\i /SQL/injection/005_clean_structure_no_comp.sql

\echo '--- 0️⃣bis Remplissage des cost / reverse_cost ---'
\i /SQL/injection/006_add_length_m_cost_reverse_cost.sql

\echo '--- 1️⃣ Création de la topologie ---'
\i /SQL/graphe/007_PGRouting_createTopology_graphe_routier.sql

\echo '--- 2️⃣ Nettoyage des arêtes avant analyse ---'
\i /SQL/graphe/008_nettoyage_aretes_avt_analyse.sql

\echo '--- 3️⃣ Analyse du graphe (pgr_analyzeGraph) ---'
\i /SQL/graphe/009_analyzeGraph.sql

\echo '--- 4️⃣ Vérification des arêtes ---'
\i /SQL/graphe/010_verification_aretes.sql

\echo '--- 5️⃣ Export des nœuds isolés/anormaux ---'
\i /SQL/graphe/011_export_vertices_geojson.sql


\echo '--- 7️⃣ Création des fonctions de routage ---'
\i /SQL/algorithmes/core/016_snap_to_nearest_node_function.sql
\i /SQL/algorithmes/core/017_dijkstra_snap.sql

\echo '--- 8️⃣ Stress test du routage complet (tour de ville multipoints) ---'
\i /SQL/algorithmes/tests/018_stress_test_dijkstra_snap.sql

\echo '--- ✅ Pipeline complet exécuté avec succès ---'


\o 

\echo '--- Temps total d’exécution du pipeline ---'
SELECT now() AS fin_pipeline;

-- dernier test en psql : SELECT dijkstra_snap(46.9896, 3.1589, 46.9923, 3.1701); => doit renvoyer un geojson dans le terminal
