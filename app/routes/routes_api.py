from flask import Blueprint, jsonify, request
import psycopg2
from config import Config

routes_api = Blueprint("routes_api", __name__)

def get_db_conn():
    return psycopg2.connect(
        host=Config.DB_HOST,
        port=Config.DB_PORT,
        database=Config.DB_NAME,
        user=Config.DB_USER,
        password=Config.DB_PASSWORD
    )

@routes_api.route("/api/test_db", methods=["GET"])
def test_db():
    try:
        conn = get_db_conn()
        conn.close()
        return jsonify({"status": "success", "message": "Database connection is a success !"})
    except Exception as e:
        return jsonify({"status": "error", "message": e.pgerror or str(e)}), 500

@routes_api.route("/api/route", methods=["GET"])
def get_route():
    try:
        lat1 = request.args.get("lat1", type=float)
        lon1 = request.args.get("lon1", type=float)
        lat2 = request.args.get("lat2", type=float)
        lon2 = request.args.get("lon2", type=float)

        if None in (lat1, lon1, lat2, lon2):
            return jsonify({
                "status": "error",
                "message": "Missing parameters. Expected :lat1, lon1, lat2, lon2"
            }), 400
        
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute(
            "SELECT export_api_route_feature_api(%s, %s, %s, %s);",
            (lat1, lon1, lat2, lon2)
        )
        result = cur.fetchone()[0]
        cur.close()
        conn.close()

        return jsonify(result), 200
    except psycopg2.Error as e:
        return jsonify({"status" : "error","message" : e.pgerror or str(e)}), 500
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


