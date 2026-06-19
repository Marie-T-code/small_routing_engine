# app.py — application entry point
# Layer : App
# Creates the Flask instance, registers all blueprints, and starts the server.

from flask import Flask, send_from_directory
from config import Config
from routes.blueprint import blueprint_route
from pois.blueprint import blueprint_pois
from blueprint_health import blueprint_health

def create_app():
    app = Flask(__name__)
    app.register_blueprint(blueprint_route)
    app.register_blueprint(blueprint_pois)
    app.register_blueprint(blueprint_health)

    @app.route("/")
    def index():
        return send_from_directory(app.static_folder, "index.html")

    return app

if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=Config.FLASK_PORT, debug=Config.FLASK_DEBUG)