import os
import sys

class Config:
    # --- Configuration Flask ---
    FLASK_ENV = os.getenv("FLASK_ENV")
    FLASK_PORT = int(os.getenv("FLASK_PORT"))

    # --- Configuration Base de données ---
    DB_HOST = os.getenv("DB_HOST")
    DB_PORT = os.getenv("DB_PORT")
    DB_NAME = os.getenv("DB_NAME")
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")

    # ✅ Vérification des variables critiques
    REQUIRED_VARS = ["DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD"]
    for var in REQUIRED_VARS:
        if os.getenv(var) is None:
            sys.exit(f"💀 ERREUR : variable d'environnement manquante → {var}")