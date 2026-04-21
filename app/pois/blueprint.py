from flask import Blueprint, jsonify, request
import psycopg2
from config import Config
from pois.repository import POIRepository
from pois.service import POIService
from pois.dto import POISearchRequest
from pois.enums import POICategory

blueprint_pois = Blueprint("blueprint_pois", __name__)

def get_db_conn():
    return psycopg2.connect(
        host=Config.DB_HOST,
        port=Config.DB_PORT,
        database=Config.DB_NAME,
        user=Config.DB_USER,
        password=Config.DB_PASSWORD
    )

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
                "message": "missing parameters. Expected : lat_start, lat_end, lon_start, lon_end, category, raduis_m"
            }), 400
        
        category = POICategory(category)
        
        conn = get_db_conn()
        repo = POIRepository(conn)
        service = POIService(repo)
        POISearch = POISearchRequest(lat_start, lon_start, lat_end, lon_end, category, radius_m)

        pois = service.search(POISearch)
        result = pois.to_geojson()
        
        return jsonify(result), 200
    except psycopg2.Error as e:
        return jsonify({"status" : "error","message" : e.pgerror or str(e)}), 500
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if conn:
            conn.close()

