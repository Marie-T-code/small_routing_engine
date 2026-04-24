# config.py — environment configuration and database connection
# Layer : Config
# Loads environment variables, validates required ones at startup, exposes get_db_conn().

import os
import sys
import psycopg2

class Config:
    # --- Configuration Flask ---
    FLASK_DEBUG = os.getenv("FLASK_DEBUG", "False").lower() == "true"
    FLASK_PORT = int(os.getenv("FLASK_PORT"))

    # --- Configuration Base de données ---
    PGHOST = os.getenv("PGHOST")
    PGPORT = os.getenv("PGPORT")
    PGDATABASE = os.getenv("PGDATABASE")
    PGUSER = os.getenv("PGUSER")
    PGPASSWORD = os.getenv("PGPASSWORD")

    # Critical variables check
    REQUIRED_VARS = ["PGHOST", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD"]
    for var in REQUIRED_VARS:
        if os.getenv(var) is None:
            sys.exit(f"ERROR : environment variable missing → {var}")


# Standalone utility function — creates and returns a new psycopg2 connection.
# Used by all blueprints. Each request opens its own connection and closes it in finally.

def get_db_conn():
    return psycopg2.connect(
        host=Config.PGHOST,
        port=Config.PGPORT,
        database=Config.PGDATABASE,
        user=Config.PGUSER,
        password=Config.PGPASSWORD
    )