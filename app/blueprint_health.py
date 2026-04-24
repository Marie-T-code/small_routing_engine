# blueprint_health.py — HTTP blueprint for health checks
# Layer : Blueprint
# Exposes /api/test_db to verify database connectivity. Used by Docker healthcheck.


from flask import Blueprint, jsonify, request
from config import get_db_conn

blueprint_health = Blueprint("blueprint_health", __name__)

@blueprint_health.route("/api/test_db", methods=["GET"])
def test_db():
    try:
        conn = get_db_conn()
        conn.close()
        return jsonify({"status": "success", "message": "Database connection is a success !"})
    except Exception as e:
        return jsonify({"status": "error", "message": e.pgerror or str(e)}), 500