#!/bin/bash
# test_api.sh — curl test suite for small_routing_engine API
# Usage : bash test_api.sh
# Expected : all tests PASS

BASE_URL="http://localhost:5000"

PASS=0
FAIL=0

check() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [ "$actual" = "$expected" ]; then
        echo "  PASS  $label"
        ((PASS++))
    else
        echo "  FAIL  $label"
        echo "        expected : $expected"
        echo "        got      : $actual"
        ((FAIL++))
    fi
}

# ---------------------------------------------------------------------------
# /api/test_db
# ---------------------------------------------------------------------------
echo ""
echo "=== /api/test_db ==="

# [NOMINAL] DB reachable
check "[NOMINAL] DB reachable → 200" "200" \
    "$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/test_db")"


# ---------------------------------------------------------------------------
# /api/coverage
# ---------------------------------------------------------------------------
echo ""
echo "=== /api/coverage ==="

# [NOMINAL] graph coverage bbox
check "[NOMINAL] coverage bbox → 200" "200" \
    "$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/coverage")"


# ---------------------------------------------------------------------------
# /api/route
# ---------------------------------------------------------------------------
echo ""
echo "=== /api/route ==="

# [NOMINAL] short urban route (~2km, one-way respected)
check "[NOMINAL] short route → 200" "200" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route?lat1=46.9868901&lon1=3.1697954&lat2=46.98779081&lon2=3.16548461&speed_kmh=15")"

# [NOMINAL] long route (~33km)
check "[NOMINAL] long route → 200" "200" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route?lat1=46.86025&lon1=3.16577&lat2=47.1189&lon2=3.26215&speed_kmh=15")"

# [ERROR] same point as start and end — no path found → 404
check "[ERROR] same point start=end → 404" "404" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route?lat1=46.9868901&lon1=3.1697954&lat2=46.9868901&lon2=3.1697954&speed_kmh=15")"

# [ERROR] speed_kmh missing → 400
check "[ERROR] speed_kmh missing → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route?lat1=46.9868901&lon1=3.1697954&lat2=46.98779081&lon2=3.16548461")"

# [ERROR] lat1 missing → 400
check "[ERROR] lat1 missing → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route?lon1=3.1697954&lat2=46.98779081&lon2=3.16548461&speed_kmh=15")"

# [ERROR] all parameters missing → 400
check "[ERROR] all parameters missing → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route")"

# [ERROR] speed_kmh = 9 (too low, <= 10) → 400
check "[ERROR] speed_kmh=9 too low → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route?lat1=46.9868901&lon1=3.1697954&lat2=46.98779081&lon2=3.16548461&speed_kmh=9")"

# [ERROR] speed_kmh = 26 (too high, > 25) → 400
check "[ERROR] speed_kmh=26 too high → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route?lat1=46.9868901&lon1=3.1697954&lat2=46.98779081&lon2=3.16548461&speed_kmh=26")"

# [ERROR] coordinates out of coverage zone (Paris — Alésia / Gare de l'Est) → 422
check "[ERROR] out of coverage zone → 422" "422" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/route?lat1=48.827867&lon1=2.326583&lat2=48.876789&lon2=2.359446&speed_kmh=15")"


# ---------------------------------------------------------------------------
# /api/pois_search
# ---------------------------------------------------------------------------
echo ""
echo "=== /api/pois_search ==="

# [NOMINAL] valid request along short route, category=bike, radius=200m
check "[NOMINAL] pois_search → 200" "200" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/pois_search?lat_start=46.9868901&lon_start=3.1697954&lat_end=46.98779081&lon_end=3.16548461&category=bike&radius_m=200")"

# [ERROR] category missing → 400
check "[ERROR] category missing → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/pois_search?lat_start=46.9868901&lon_start=3.1697954&lat_end=46.98779081&lon_end=3.16548461&radius_m=200")"

# [ERROR] radius_m missing → 400
check "[ERROR] radius_m missing → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/pois_search?lat_start=46.9868901&lon_start=3.1697954&lat_end=46.98779081&lon_end=3.16548461&category=bike")"

# [ERROR] category invalid ("zombie") → 400
check "[ERROR] category=zombie invalid → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/pois_search?lat_start=46.9868901&lon_start=3.1697954&lat_end=46.98779081&lon_end=3.16548461&category=zombie&radius_m=200")"

# [ERROR] radius_m = 5 (too small, <= 10) → 400
check "[ERROR] radius_m=5 too small → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/pois_search?lat_start=46.9868901&lon_start=3.1697954&lat_end=46.98779081&lon_end=3.16548461&category=bike&radius_m=5")"

# [ERROR] radius_m = 2000 (too large, > 1000) → 400
check "[ERROR] radius_m=2000 too large → 400" "400" \
    "$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/pois_search?lat_start=46.9868901&lon_start=3.1697954&lat_end=46.98779081&lon_end=3.16548461&category=bike&radius_m=2000")"


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "  $PASS / $TOTAL passed"
if [ "$FAIL" -eq 0 ]; then
    echo "  All tests passed."
else
    echo "  $FAIL test(s) failed — see above."
fi
echo "========================================"
echo ""