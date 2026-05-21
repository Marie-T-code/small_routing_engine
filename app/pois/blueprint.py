# blueprint.py — HTTP blueprint for the POI search service
# Layer : Blueprint
# Exposes /api/pois_search — finds points of interest within a given radius along a route.

from flask import Blueprint, jsonify, request
from config import get_db_conn
from pois.repository import POIRepository
from pois.service import POIService
from pois.dto import POISearchRequest
from pois.enums import POICategory
from pois.exceptions import POIRouteNotFoundError, InvalidRadiusError
from utils.db_errors import parse_pg_error_message

blueprint_pois = Blueprint("blueprint_pois", __name__)


@blueprint_pois.route("/api/pois_search", methods=["GET"])
def get_route():
    conn = None
    try:
        lat_start = request.args.get("lat_start", type=float)
        lon_start = request.args.get("lon_start", type=float)
        lat_end = request.args.get("lat_end", type=float)
        lon_end = request.args.get("lon_end", type=float)
        category = request.args.get("category")
        radius_m = request.args.get("radius_m", type=float)

        if None in (lat_start, lon_start, lat_end, lon_end, category, radius_m):
            return jsonify({
                "status": "error",
                "message": "missing parameters. Expected : lat_start, lat_end, lon_start, lon_end, category, radius_m"
            }), 400
        
        category = POICategory(category)
        
        conn = get_db_conn()
        repo = POIRepository(conn)
        service = POIService(repo)
        POISearch = POISearchRequest(lat_start, lon_start, lat_end, lon_end, category, radius_m)

        pois = service.search(POISearch)
        result = pois.to_geojson() 
        
        return jsonify(result), 200
    except ValueError:
        return jsonify({
            "status": "error",
            "message": "Invalid category. Expected : bike, culture, services, catering"
        }), 400
    except InvalidRadiusError as e:
        return jsonify({"status": "error", "message": str(e)}), 400
    except POIRouteNotFoundError as e:
        message = parse_pg_error_message(str(e))
        return jsonify({"status": "error", "message": message}), 404
    except Exception:
        return jsonify({"status": "error", "message": "An unexpected error occurred"}), 500
    finally:
        if conn:
            conn.close()

