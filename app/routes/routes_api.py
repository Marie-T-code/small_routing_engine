from flask import Blueprint, jsonify
import psycopg2
from config import Config

routes_api = Blueprint("routes_api", __name__)

@routes_api.route("/api/test_db", methods=["GET"])
def test_db():
    try:
        conn = psycopg2.connect(
            host=Config.DB_HOST,
            port=Config.DB_PORT,
            database=Config.DB_NAME,
            user=Config.DB_USER,
            password=Config.DB_PASSWORD
        )
        conn.close()
        return jsonify({"status": "success", "message": "Connexion réussie à la base de données !"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
