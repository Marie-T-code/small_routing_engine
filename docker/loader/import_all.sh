#!/bin/bash
# ---------------------------------------------------------------------
# import_all.sh
# Master import script — runs all data loaders in order
# ---------------------------------------------------------------------
set -euo pipefail

echo "======================================================"
echo " Starting full data import"
echo "======================================================"

bash /SQL/03_injection/import_routes.sh
bash /SQL/03_injection/import_pois.sh

echo "======================================================"
echo "✅ All imports completed successfully."
echo "======================================================"