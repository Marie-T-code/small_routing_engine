#!/bin/bash
# ---------------------------------------------------------------------
# 01_import_routes.sh
# Import cleaned road network from a GeoPackage into PostGIS
# ---------------------------------------------------------------------
set -euo pipefail

# Load environment variables from .env
set -a
[ -f .env ] && . ./.env
set +a

# Connection-related variables not stored in the env file
# (data path, destination table, and GeoPackage layer name)
DATAPATH="/import/nevers_clean.gpkg"   # Path inside the container
LAYER="roads_clean_v1"                 # Layer name inside the GeoPackage
TABLE="public.routes_v1"               # Destination table name

echo "[import] truncating ${TABLE} (keep schema)..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "${PGHOST}" -p "${PGPORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 \
  -c "TRUNCATE TABLE ${TABLE};"

echo "------------------------------------------------------"
echo " Importing ${LAYER} into database ${POSTGRES_DB} (${TABLE})"
echo "------------------------------------------------------"

# Set PGPASSWORD only for this command
PGPASSWORD="$POSTGRES_PASSWORD" ogr2ogr \
  -f "PostgreSQL" PG:"host=${PGHOST} dbname=${POSTGRES_DB} user=${POSTGRES_USER} port=${PGPORT}" \
  "${DATAPATH}" "${LAYER}" \
  -nln ${TABLE} \
  -lco GEOMETRY_NAME=geom \
  -nlt LINESTRING \
  -a_srs EPSG:2154 \
  -append -addfields

echo "✅ Import successful: ${TABLE} populated."

# ────────────────────────────────────────────────
# 🔧 Running the import script inside Docker
#
# → Run from the project root directory
#
# PowerShell:
#   docker exec -it nevers_postgis bash -c "/SQL/03_injection/import_routes.sh"
#
# Git Bash / Linux / macOS:
#   docker exec -it nevers_postgis bash -c "bash /SQL/03_injection/import_routes.sh"
#
# ────────────────────────────────────────────────
# ✅ Import validation test:
#   docker exec -it nevers_postgis psql \
#     -U $POSTGRES_USER \
#     -d $POSTGRES_DB \
#     -c "SELECT COUNT(*) FROM routes_v1;"
# ────────────────────────────────────────────────
