#!/usr/bin/env bash
set -euo pipefail

echo "[builder] waiting db..."
while true; do
  if psql -h db -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 -c "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[builder] running master..."
psql -h db -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 \
  -f "/SQL/06_MASTERS/90_MASTER_ALL.sql"

echo "[builder] done"