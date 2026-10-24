# config.py — environment configuration and database connection
# Layer : Config
# Loads environment variables, validates required ones at startup, exposes get_db_conn().
# Single source of truth: exits at startup if a required variable is missing or empty.

import os
import sys

import psycopg2


# Critical variables check
def _check_required_vars():
    required_vars = (
        "PGHOST", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD",
        "FLASK_DEBUG", "FLASK_PORT")
    for var in required_vars:
        if not os.getenv(var):
            sys.exit(f"ERROR : environment variable missing or empty → {var}")


_check_required_vars()


class Config:
    # --- DB config ---

    PGHOST = os.getenv("PGHOST")
    PGPORT = os.getenv("PGPORT")
    PGDATABASE = os.getenv("PGDATABASE")
    PGUSER = os.getenv("PGUSER")
    PGPASSWORD = os.getenv("PGPASSWORD")

    # --- Flask Config ---

    # Same rule as Flask: anything except "0", "false", "no" enables debug
    FLASK_DEBUG = os.getenv("FLASK_DEBUG").lower() not in {"0", "false", "no"}
    try:
        FLASK_PORT = int(os.getenv("FLASK_PORT"))
    except ValueError:
        sys.exit(f"ERROR : FLASK_PORT must be an integer, got {os.getenv('FLASK_PORT')!r}")


def get_db_conn():
    """Create and return a new psycopg2 connection.
    
    Used by all blueprints: each request opens its own connection
    and closes it in its `finally` block.
    """
    return psycopg2.connect(
        host=Config.PGHOST,
        port=Config.PGPORT,
        dbname=Config.PGDATABASE,
        user=Config.PGUSER,
        password=Config.PGPASSWORD
    )
