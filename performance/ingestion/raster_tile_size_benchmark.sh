#!/bin/bash
# ---------------------------------------------------------------------
# raster_tile_size_benchmark.sh
#
# ONE-SHOT benchmark. Not part of the pipeline, not meant to be replayed.
# Purpose: decide the raster2pgsql -t tile size for import_dem.sh by
# measuring, for each candidate size, the trade-off between:
#   - import time      (raster2pgsql | psql, incl. GiST index build)
#   - table footprint  (row count + total size on disk)
#   - point-lookup time (ST_Value at every routes_v1 start point)
#
# The point-lookup query mimics the real access pattern of the future
# slope computation: thousands of scattered ST_Value reads, one per edge.
# It is a JOIN (not the production correlated sub-select) because we only
# need the RELATIVE cost across tile sizes, not an absolute figure.
#
# Runs against a throwaway table (dem_test), dropped and recreated on
# each pass via -d, so passes are independent and the real dem_nevers
# table is never touched.
#
# Invocation (from project root, output captured host-side):
#   docker compose run --rm loader \
#     bash /performance/ingestion/raster_tile_size_benchmark.sh \
#     2>&1 | tee performance/ingestion/raster_tile_size_benchmark_raw.txt
# ---------------------------------------------------------------------
set -euo pipefail

set -a
[ -f .env ] && . ./.env
set +a

DEM="/import/dem_nevers.tif"
TABLE="public.dem_test"
TILES=(32 64 100 256)

# Reusable psql connection (server-side work only; no password needed on
# raster2pgsql, which does not connect — it only emits SQL to stdout).
psql_run() {
    PGPASSWORD="$POSTGRES_PASSWORD" psql \
        -h "${PGHOST}" -p "${PGPORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
        -v ON_ERROR_STOP=1 "$@"
}

echo "######################################################"
echo "# DEM tile-size benchmark"
echo "# source : ${DEM}"
echo "# table  : ${TABLE} (throwaway)"
echo "# sizes  : ${TILES[*]}"
echo "######################################################"

for T in "${TILES[@]}"; do
    echo ""
    echo "======================================================"
    echo "=== tile ${T}x${T} ==="
    echo "======================================================"

    echo "--- import time (raster2pgsql + psql, incl. -I index) ---"
    # -d drop+create each pass  |  -I GiST index  |  -C constraints  |  -s SRID
    time ( raster2pgsql -s 2154 -d -C -I -M -t "${T}x${T}" "${DEM}" "${TABLE}" \
        | PGPASSWORD="$POSTGRES_PASSWORD" psql \
            -h "${PGHOST}" -p "${PGPORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
            -q -v ON_ERROR_STOP=1 )

    echo "--- tiles + on-disk footprint ---"
    psql_run -c "
        SELECT count(*) AS nb_tiles,
                pg_size_pretty(pg_total_relation_size('${TABLE}')) AS table_size
        FROM ${TABLE};"

    echo "--- point-lookup time (ST_Value at every routes_v1 start point) ---"
    psql_run -c "\timing on" -c "
        SELECT count(alt) AS points_read
            FROM routes_v1 r
            CROSS JOIN LATERAL (
                SELECT ST_Value(d.rast, ST_StartPoint(r.geom)) AS alt
                FROM ${TABLE} d
                WHERE d.rast && ST_StartPoint(r.geom)
                    AND ST_Intersects(d.rast, ST_StartPoint(r.geom))
                LIMIT 1
            ) s;"
done

echo ""
echo "--- cleanup: dropping throwaway table ---"
psql_run -c "DROP TABLE IF EXISTS ${TABLE};"

echo ""
echo "✅ benchmark complete."