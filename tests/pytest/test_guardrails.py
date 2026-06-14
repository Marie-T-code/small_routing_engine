# tests/pytest/test_guardrails.py
# Wraps the SQL guardrail test suites, executed inside the db container of the
# testcontainers-managed stack. Each suite raises on the first failing case
# under ON_ERROR_STOP=1, so a non-zero psql exit code means a guardrail failed.

GUARDRAIL_DIR = "/SQL/XX_tests/guardrails"


def run_guardrail_suite(running_stack, filename):
    # exec_in_container(command, service_name) -> (stdout, stderr, exit_code)
    stdout, stderr, exit_code = running_stack.exec_in_container(
        ["psql", "-v", "ON_ERROR_STOP=1", "-f", f"{GUARDRAIL_DIR}/{filename}"],
        service_name="db",
    )
    return stdout, stderr, exit_code


# [EXPECTED_SUCCESS] preconditions guardrail suite passes (all cases caught) -> exit 0
def test_preconditions_guardrails(running_stack):
    stdout, stderr, exit_code = run_guardrail_suite(
        running_stack, "assert_graph_preconditions_on_test.sql"
    )
    assert exit_code == 0, stdout + stderr


# [EXPECTED_SUCCESS] ready guardrail suite passes (all cases caught) -> exit 0
def test_ready_guardrails(running_stack):
    stdout, stderr, exit_code = run_guardrail_suite(
        running_stack, "assert_graph_ready_on_test.sql"
    )
    assert exit_code == 0, stdout + stderr