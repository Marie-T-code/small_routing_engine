# blueprint.py — HTTP blueprint for the POI search service
# Layer : Blueprint
# Exposes /api/pois_search — finds points of interest within a given radius along a route.

from flask import Blueprint, jsonify, request

from config import get_db_conn
from pois.repository import POIRepository
from pois.service import POIService
from pois.dto import POISearchRequest


blueprint_pois = Blueprint("blueprint_pois", __name__)


@blueprint_pois.route("/api/pois_search", methods=["GET"])
def search_pois():
    lat_start = request.args.get("lat_start", type=float)
    lon_start = request.args.get("lon_start", type=float)
    lat_end = request.args.get("lat_end", type=float)
    lon_end = request.args.get("lon_end", type=float)
    category = request.args.get("category")
    radius_m = request.args.get("radius_m", type=float)
    if None in (lat_start, lon_start, lat_end, lon_end, category, radius_m):
        return jsonify({
            "status": "error",
            "message": "Missing or invalid parameters."
            " Expected: lat_start, lon_start, lat_end, lon_end, category, radius_m"
        }), 400
    poi_search = POISearchRequest(lat_start, lon_start, lat_end, lon_end, category, radius_m)
    conn = get_db_conn()
    try:
        repo = POIRepository(conn)
        service = POIService(repo)
        pois = service.search(poi_search)
        result = pois.to_geojson()
        return jsonify(result), 200
    finally:
        conn.close()
