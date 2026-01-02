from flask import Flask
from flask_cors import CORS
from config import Config
from routes.routes_api import routes_api

def create_app():
    app = Flask(__name__)
    CORS(app)  # Autorise les requêtes cross-origin (utile pour le front)
    app.register_blueprint(routes_api)
    return app

if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=Config.FLASK_PORT, debug=Config.FLASK_ENV == "development")