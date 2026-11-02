# blueprint_health.py — HTTP blueprint for health checks
# Layer : Blueprint
# Exposes /api/test_db to verify database connectivity. Used by Docker healthcheck.

import logging

from flask import Blueprint, jsonify

from config import get_db_conn

logger = logging.getLogger(__name__)

blueprint_health = Blueprint("blueprint_health", __name__)


@blueprint_health.route("/api/test_db", methods=["GET"])
def test_db():
    try:
        conn = get_db_conn()
        conn.close()
        return jsonify({"status": "success", "message": "Database connection successful"})
    except Exception:
        logger.exception("Health check failed: cannot reach the database")
        return jsonify({"status": "error", "message": "Database unreachable"}), 503
