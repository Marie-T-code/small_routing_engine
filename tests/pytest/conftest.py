import os
import sys
from pathlib import Path
import pytest
from testcontainers.compose import DockerCompose
from dotenv import dotenv_values

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
env = dotenv_values(PROJECT_ROOT / ".env")
sys.path.insert(0, str(PROJECT_ROOT / "app"))


def _wait_until_graph_ready(
    host, port, dbname, user, password, timeout=180
    ):
    """
    Poll the DB until the builder has finished: graph_coverage must hold a row.
    docker compose --wait does NOT guarantee the builder task has completed,
    so we verify the real end-state.
    """
    import time
    import psycopg2
    deadline = time.time() + timeout
    last_err = None
    while time.time() < deadline:
        try:
            conn = psycopg2.connect(host=host, port=port,
            dbname=dbname, user=user, password=password)
            cur = conn.cursor()
            cur.execute("SELECT count(*) FROM graph_coverage;")
            ready = cur.fetchone()[0] > 0
            conn.close()
            if ready:
                return
        except Exception as e:
            last_err = e
        time.sleep(3)
    raise TimeoutError(f"Graph not ready after {timeout}s. Last error: {last_err}")


@pytest.fixture(scope="session")
def running_stack():
    """
    Owns the docker-compose lifecycle: brings the db/loader/builder chain up
    once per session, waits until the graph is actually built, then yields the
    live DockerCompose object so callers can exec commands inside its containers.
    Single source of truth for the running stack.
    """
    os.environ["COMPOSE_PROFILES"] = "pipeline"

    compose = DockerCompose(
        str(PROJECT_ROOT),
        compose_file_name="docker-compose.yaml",
        build=True,
        services=["db", "loader", "builder"],
    )

    with compose:
        host = compose.get_service_host("db", 5432)
        if host == "0.0.0.0":
            host = "127.0.0.1"
        port = int(compose.get_service_port("db", 5432))

        _wait_until_graph_ready(
            host, port,
            dbname=env["PGDATABASE"], user=env["PGUSER"], password=env["PGPASSWORD"],
        )

        yield compose
    # leaving the with block -> docker compose down


@pytest.fixture(scope="session")
def db_coords(running_stack):
    """
    Derives the DB connection coordinates from the running stack.
    Depends on running_stack, so the chain is already up and the graph ready.
    No lifecycle of its own — single responsibility: connection info.
    """
    host = running_stack.get_service_host("db", 5432)
    if host == "0.0.0.0":
        host = "127.0.0.1"
    port = int(running_stack.get_service_port("db", 5432))

    return {
        "host": host,
        "port": port,
    }


@pytest.fixture(scope="session")
def client(db_coords):
    """Flask test client wired to the containerised DB.

    Credentials come from .env (single source of truth, shared with compose).
    Host/port come from the running container (dynamic), never from a file.
    config.py validates required env vars at import, so we populate them all
    BEFORE importing create_app.
    """

    # Credentials: static, from .env (single source of truth).
    os.environ["PGDATABASE"] = env["PGDATABASE"]
    os.environ["PGUSER"] = env["PGUSER"]
    os.environ["PGPASSWORD"] = env["PGPASSWORD"]

    # Host/port: dynamic, from the running container (never from a file).
    os.environ["PGHOST"] = db_coords["host"]
    os.environ["PGPORT"] = str(db_coords["port"])

    # FLASK_PORT: config.py crashes on int(None); value irrelevant for tests.
    os.environ["FLASK_PORT"] = env.get("FLASK_PORT", "5000")

    from app import create_app

    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c