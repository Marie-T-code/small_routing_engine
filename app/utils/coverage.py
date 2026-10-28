# coverage.py — shared coverage check; used by every repository
# Layer : Repository (shared helper)

import psycopg2

from utils.db_errors import parse_pg_error_code, parse_pg_error_message
from utils.exceptions import PointOutOfCoverageError


def check_within_coverage(connection, lat: float, lon: float) -> None:
    """Raise PointOutOfCoverageError if (lat, lon) is outside the graph coverage."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT is_within_coverage(%s, %s)", (lat, lon))
    except psycopg2.Error as e:
        message = e.diag.message_primary
        if parse_pg_error_code(message) == 'COVERAGE:OUT_OF_BOUNDS':
            raise PointOutOfCoverageError(parse_pg_error_message(message)) from e
        raise
