# blueprint.py — HTTP blueprint for the routing engine
# Layer : Blueprint
# Exposes /api/route — computes a Dijkstra-based bicycle route and returns GeoJSON.
# Exposes /api/coverage — shows the graph bounding box


from flask import Blueprint, jsonify, request
from config import get_db_conn
from routes.repository import RouteRepository
from routes.service import RouteService
from routes.dto import RouteSearchRequest
from utils.db_errors import parse_pg_error_message
import logging
from routes.exceptions import RouteNotFoundError, InvalidCoordinatesError, InvalidSpeedError
from utils.exceptions import PointOutOfCoverageError, SamePointError

logger = logging.getLogger(__name__)

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
    except InvalidCoordinatesError as e:
        return jsonify({"status": "error", "message": str(e)}), 400
    except InvalidSpeedError as e:
        return jsonify({"status": "error", "message": str(e)}), 400
    except SamePointError as e:
        return jsonify({"status": "error", "message": str(e)}), 400
    except PointOutOfCoverageError as e:
        message = parse_pg_error_message(str(e))
        return jsonify({"status": "error", "message": message}), 422
    except RouteNotFoundError as e:
        message = parse_pg_error_message(str(e))
        return jsonify({"status": "error", "message": message}), 404
    except Exception as e:
        logger.exception("Unhandled error on %s", request.path)
        return jsonify({"status": "error", "message": "An unexpected error occurred"}), 500
    finally:
        if conn:
            conn.close()


@blueprint_route.route("/api/coverage", methods=["GET"])
def get_coverage():
    conn = None
    try:
        conn = get_db_conn()
        repo = RouteRepository(conn)
        service = RouteService(repo)
        get_coverage = service.get_coverage()

        return jsonify(get_coverage), 200
    except Exception as e:
        logger.exception("Unhandled error on %s", request.path)
        return jsonify({"status": "error", "message": "An unexpected error occurred"}), 500
    finally:
        if conn:
            conn.close()