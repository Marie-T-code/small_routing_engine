# config.py — environment configuration and database connection
# Layer : Config
# Loads environment variables, validates required ones at startup, exposes get_db_conn().
# Single source of truth: DB vars are checked at import, server vars when the dev server starts.

import os
import sys

import psycopg2

DB_VARS = ("PGHOST", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD")
SERVER_VARS = ("FLASK_DEBUG", "FLASK_PORT")


# Critical variables check
def _check_required_vars(names):
    for var in names:
        if not os.getenv(var):
            sys.exit(f"ERROR : environment variable missing or empty → {var}")


_check_required_vars(DB_VARS)


class Config:

    PGHOST = os.getenv("PGHOST")
    PGPORT = os.getenv("PGPORT")
    PGDATABASE = os.getenv("PGDATABASE")
    PGUSER = os.getenv("PGUSER")
    PGPASSWORD = os.getenv("PGPASSWORD")


def get_server_settings():
    """Validate and return the dev-server settings as (port, debug).

    Only called when launching the dev server (app.py __main__),
    so imports and tests never need the FLASK_* variables.
    """
    _check_required_vars(SERVER_VARS)
    # Same rule as Flask: anything except "0", "false", "no" enables debug
    debug = os.getenv("FLASK_DEBUG").lower() not in {"0", "false", "no"}
    try:
        port = int(os.getenv("FLASK_PORT"))
    except ValueError:
        sys.exit(f"ERROR : FLASK_PORT must be an integer, got {os.getenv('FLASK_PORT')!r}")
    return port, debug


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
