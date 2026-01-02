#!/bin/bash
# ---------------------------------------------------------------------
# 01_import_routes.sh
# Import du réseau de routes nettoyé depuis le GeoPackage vers PostGIS
# ---------------------------------------------------------------------
set -euo pipefail

 
# Charger les variables d'environnement (.env)
set -a
[ -f .env ] && . ./.env
set +a
# Variables de connexion absentes de l'env (chemin des tables, table, et layer du gpkg)
DATAPATH="/import/nevers_clean.gpkg" #chemin du dossier courant, si on n'est pas dans le conteneur docker dans le terminal utiliser ce chemin
LAYER="roads_clean_v1"   # nom de la couche dans le .gpkg
TABLE="routes_v1"            # table de destination

echo "------------------------------------------------------"
echo " Import de ${LAYER} dans la base ${POSTGRES_DB} (${TABLE})"
echo "------------------------------------------------------"

 # définir PGPASSWORD uniquement pour cette commande 
PGPASSWORD="$POSTGRES_PASSWORD" ogr2ogr\
  -f "PostgreSQL" PG:"host=localhost dbname=${POSTGRES_DB} user=${POSTGRES_USER} port=${PG_PORT}"\
  "${DATAPATH}" "${LAYER}"\
  -nln ${TABLE}\
  -lco GEOMETRY_NAME=geom\
  -nlt LINESTRING\
  -a_srs EPSG:2154\
  -append -addfields

  echo "✅ Import réussi : ${TABLE} remplie."

# ────────────────────────────────────────────────
# 🔧 Exécution du script d'import dans Docker
#
# → À lancer depuis le dossier racine du projet
#
# Sous PowerShell :
#   docker exec -it nevers_postgis bash -c "/SQL/injection/004_import_routes.sh"
#
# Sous Git Bash / Linux / Mac :
#   docker exec -it nevers_postgis bash -c "bash /SQL/injection/004_import_routes.sh"
#
# ────────────────────────────────────────────────
# ✅ Test de validité de l'import :
#   docker exec -it nevers_postgis psql \
#     -U $POSTGRES_USER \
#     -d $POSTGRES_DB \
#     -c "SELECT COUNT(*) FROM routes_v1;"
# ────────────────────────────────────────────────
 


