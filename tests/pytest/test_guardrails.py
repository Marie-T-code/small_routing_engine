# tests/pytest/test_guardrails.py
# Wraps the SQL guardrail test suites (run inside the db container via psql).
# Each suite raises on the first failing case under ON_ERROR_STOP=1, so a
# non-zero psql exit code means at least one guardrail case failed.
# NOTE: requires the db container to be up AND the graph to be built
#       (the "ready" suite checks against the real routing_edges/vertices views).

import subprocess

DB_SERVICE = "db"
GUARDRAIL_DIR = "/SQL/XX_tests/guardrails"


def run_guardrail_suite(filename):
    # No -U / -d : user and database are provided by the container's own
    # environment (PGUSER / PGDATABASE from the .env injected by compose),
    # same as the `make psql` command.
    return subprocess.run(
        ["docker", "compose", "exec", "-T", DB_SERVICE,
        "psql",
        "-v", "ON_ERROR_STOP=1",
        "-f", f"{GUARDRAIL_DIR}/{filename}"],
        capture_output=True, text=True,
    )


# [EXPECTED_SUCCESS] preconditions guardrail suite passes (all cases caught) -> exit 0
def test_preconditions_guardrails():
    result = run_guardrail_suite("assert_graph_preconditions_on_test.sql")
    assert result.returncode == 0, result.stdout + result.stderr


# [EXPECTED_SUCCESS] ready guardrail suite passes (all cases caught) -> exit 0
def test_ready_guardrails():
    result = run_guardrail_suite("assert_graph_ready_on_test.sql")
    assert result.returncode == 0, result.stdout + result.stderr

