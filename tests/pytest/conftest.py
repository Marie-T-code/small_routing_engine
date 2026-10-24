import os
import sys
import time
from pathlib import Path

import pytest
from dotenv import dotenv_values
from testcontainers.compose import DockerCompose


TEST_ENV = {
    "COMPOSE_PROJECT_NAME": "sre_test",
    "COMPOSE_PROFILES": "pipeline",
    "PG_PORT": "0", # 0 = OS picks a free host port (no collisions); read back via get_service_port()
}
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
env = dotenv_values(PROJECT_ROOT / ".env")
sys.path.insert(0, str(PROJECT_ROOT / "app"))


def _wait_until_builder_done(compose, timeout=180):
    """Block until the builder container exits, then check its exit code.

    Exit code 0 means the whole SQL pipeline ran (set -e + ON_ERROR_STOP=1),
    so the graph is ready. Any other exit code, or the timeout, aborts the
    whole session (pytest.exit) with the last builder log lines: no test can
    run without a built graph.
    Replaces the former graph_coverage poll: that row is written before the
    builder finishes, so it was not a reliable readiness signal.
    """
    deadline = time.time() + timeout
    builder = None
    while time.time() < deadline:
        builder = compose.get_container("builder", include_all=True)
        if builder.State == "exited":
            if builder.ExitCode == 0:
                return
            stdout, _ = compose.get_logs("builder")
            tail = "\n".join(stdout.splitlines()[-30:])
            pytest.exit(f"builder exited {builder.ExitCode} (last 30 log lines):\n{tail}")
        time.sleep(3)
    pytest.exit(f"builder not done after {timeout}s (last state: {builder.State})")


@pytest.fixture(scope="session")
def running_stack():
    """Owns the docker-compose lifecycle: brings the db/loader/builder chain up
    once per session, waits until the builder has exited successfully (end of
    the pipeline), then yields the live DockerCompose object so callers can exec
    commands inside its containers.
    Single source of truth for the running stack."""
    saved = {k: os.environ.get(k) for k in TEST_ENV}
    os.environ.update(TEST_ENV)
    try:
        compose = DockerCompose(
            str(PROJECT_ROOT),
            compose_file_name="docker-compose.yaml",
            build=True,
            services=["db", "loader", "builder"],
        )

        # Guardrail: checked BEFORE `with`, so up/down can never target the dev stack
        project = compose.get_config()["name"]
        if project != TEST_ENV["COMPOSE_PROJECT_NAME"]:
            pytest.exit(f"Unexpected Compose project: {project!r}, aborting before any up/down")

        with compose:
            _wait_until_builder_done(compose)
            yield compose
        # leaving `with` -> down --volumes; TEST_ENV is still set, so down targets sre_test
    finally:
        for k, v in saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


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
    os.environ["FLASK_PORT"] = env["FLASK_PORT"]
    os.environ["FLASK_DEBUG"] = env["FLASK_DEBUG"]

    from app import create_app

    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c