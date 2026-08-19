#!/bin/bash
# ---------------------------------------------------------------------
# import_dem.sh
# Import the Nevers DEM raster (IGN RGE ALTI) into PostGIS.
#
# Unlike import_routes.sh / import_pois.sh, there is NO separate DDL for
# this table: raster2pgsql emits the CREATE TABLE itself (the raster
# schema — rast column, constraints — depends on the import flags, so
# splitting it into a hand-written DDL would be fragile). This is the
# decision recorded earlier: dem_nevers is created entirely by
# raster2pgsql.
#
# raster2pgsql does NOT connect to the database. It writes SQL to stdout,
# which is piped into psql — hence the pipe below instead of an ogr2ogr
# direct write.
#
# Tile size -t 64x64 was chosen from the tile-size benchmark
# (performance/ingestion/): fastest point-lookup on the measured run,
# which mirrors the real access pattern of the future slope computation
# (thousands of scattered ST_Value reads, one per edge).
# ---------------------------------------------------------------------
set -euo pipefail

# Load environment variables from .env
set -a
[ -f .env ] && . ./.env
set +a

DATAPATH="/import/dem_nevers.tif"   # Path inside the container
TABLE="public.dem_nevers"           # Destination table name
TILE="64x64"                        # Chosen from tile-size benchmark

echo "------------------------------------------------------"
echo " Importing DEM ${DATAPATH} into ${POSTGRES_DB} (${TABLE})"
echo " tile size: ${TILE}"
echo "------------------------------------------------------"

# raster2pgsql flags:
#   -s 2154   assign SRID (Lambert-93, project-internal CRS)
#   -d        drop + create the table each run (reproducible import,
#             the raster equivalent of the vector TRUNCATE; destroys
#             dem_nevers if it exists — intended, for idempotent replays)
#   -C        add raster constraints (SRID, blocksize, max extent…):
#             lets the planner know raster metadata without scanning
#   -I        build the GiST index on the rast column
#   -M        VACUUM ANALYZE after load (fresh stats for the planner)
#   -t 64x64  tile size (see benchmark)
#
# raster2pgsql emits SQL on stdout -> piped into psql (it does not connect).
raster2pgsql -s 2154 -d -C -I -M -t "${TILE}" "${DATAPATH}" "${TABLE}" \
  | PGPASSWORD="$POSTGRES_PASSWORD" psql \
      -h "${PGHOST}" -p "${PGPORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
      -q -v ON_ERROR_STOP=1

echo "✅ Import successful: ${TABLE} populated."

# ────────────────────────────────────────────────
# 🔧 Running the import script inside Docker
#
# → Run from the project root directory
#
# Git Bash / Linux / macOS:
#   docker exec -it nevers_postgis bash -c "bash /SQL/03_injection/import_dem.sh"
#
# ────────────────────────────────────────────────
# ✅ Import validation test:
#   docker exec -it nevers_postgis psql \
#     -U $POSTGRES_USER \
#     -d $POSTGRES_DB \
#     -c "SELECT count(*) AS nb_tiles,
#                pg_size_pretty(pg_total_relation_size('dem_nevers')) AS size
#         FROM dem_nevers;"
# ────────────────────────────────────────────────