# app.py — application entry point
# Layer : App
# Creates the Flask instance, registers all blueprints, and starts the server.

from flask import Flask
from flask_cors import CORS
from config import Config
from routes.blueprint import blueprint_route
from pois.blueprint import blueprint_pois
from blueprint_health import blueprint_health

def create_app():
    app = Flask(__name__)
    CORS(app)  # Autorise les requêtes cross-origin (utile pour le front)
    app.register_blueprint(blueprint_route)
    app.register_blueprint(blueprint_pois)
    app.register_blueprint(blueprint_health)
    return app

if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=Config.FLASK_PORT, debug=Config.FLASK_DEBUG)