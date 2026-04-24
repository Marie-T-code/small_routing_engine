# blueprint.py — HTTP blueprint for the routing engine
# Layer : Blueprint
# Exposes /api/route — computes a Dijkstra-based bicycle route and returns GeoJSON.


from flask import Blueprint, jsonify, request
import psycopg2
from config import get_db_conn
from routes.repository import RouteRepository
from routes.service import RouteService
from routes.dto import RouteSearchRequest
from routes.exceptions import RouteNotFoundError

blueprint_route = Blueprint("blueprint_route", __name__)


@blueprint_route.route("/api/route", methods=["GET"])
def get_route():
    conn = None
    try:
        lat_start = request.args.get("lat1", type=float)
        lon_start = request.args.get("lon1", type=float)
        lat_end = request.args.get("lat2", type=float)
        lon_end = request.args.get("lon2", type=float)
        speed_kmh = request.args.get("speed_kmh", type=float)


        if None in (lat_start, lon_start, lat_end, lon_end, speed_kmh):
            return jsonify({
                "status": "error",
                "message": "Missing parameters. Expected :lat1, lon1, lat2, lon2, speed_kmh"
            }), 400
        
        conn = get_db_conn()
        repo = RouteRepository(conn)
        service = RouteService(repo)
        routeSearch = RouteSearchRequest(lat_start, lon_start, lat_end, lon_end, speed_kmh)

        route = service.search(routeSearch)


        return jsonify(route.result), 200
    except RouteNotFoundError as e:
        return jsonify({"status": "error", "message": str(e)}), 404
    except psycopg2.Error as e:
        return jsonify({"status" : "error","message" : e.pgerror or str(e)}), 500
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if conn:
            conn.close()

