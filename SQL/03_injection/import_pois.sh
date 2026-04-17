#!/bin/bash
# ---------------------------------------------------------------------
# import_pois.sh
# Import cleaned POIs from a GeoPackage into PostGIS
# ---------------------------------------------------------------------
set -euo pipefail

set -a
[ -f .env ] && . ./.env
set +a

DATAPATH="/import/nevers_clean_points.gpkg"
LAYER="nevers_clean_points"
TABLE="public.pois"

echo "[import] truncating ${TABLE} (keep schema)..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "${PGHOST}" -p "${PGPORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 \
  -c "TRUNCATE TABLE ${TABLE};"

echo "------------------------------------------------------"
echo " Importing ${LAYER} into database ${POSTGRES_DB} (${TABLE})"
echo "------------------------------------------------------"

PGPASSWORD="$POSTGRES_PASSWORD" ogr2ogr \
  -f "PostgreSQL" PG:"host=${PGHOST} dbname=${POSTGRES_DB} user=${POSTGRES_USER} port=${PGPORT}" \
  "${DATAPATH}" "${LAYER}" \
  -nln ${TABLE} \
  -lco GEOMETRY_NAME=geom \
  -nlt POINT \
  -a_srs EPSG:2154 \
  -append -addfields

echo "✅ Import successful: ${TABLE} populated."