# app.py — application entry point
# Layer : App
# Creates the Flask instance, registers all blueprints, checks graph
# readiness, and starts the server.

import logging
import sys

import psycopg2
from flask import Flask, send_from_directory

from config import Config, get_db_conn
from routes.blueprint import blueprint_route
from pois.blueprint import blueprint_pois
from blueprint_health import blueprint_health

logger = logging.getLogger(__name__)

def create_app():
    app = Flask(__name__)
    app.register_blueprint(blueprint_route)
    app.register_blueprint(blueprint_pois)
    app.register_blueprint(blueprint_health)

    @app.route("/")
    def index():
        return send_from_directory(app.static_folder, "index.html")

    return app

def check_graph_ready():
    """Startup precondition: refuse to serve an uncertified graph.
    Raises if public.assert_graph_ready() fails (or does not exist)."""
    conn = get_db_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT public.assert_graph_ready();")
    finally:
        conn.close()

if __name__ == "__main__":
    try:
        check_graph_ready()
    except psycopg2.Error:
        logger.exception("Graph not ready, refusing to start. Run the pipeline (make pipeline).")
        sys.exit(1)
    app = create_app()
    app.run(host="0.0.0.0", port=Config.FLASK_PORT, debug=Config.FLASK_DEBUG)