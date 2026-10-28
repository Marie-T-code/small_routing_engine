# repository.py — database access layer for the Route service
# Layer : Repository
# Queries PostGIS (export_route_api()) to compute a route.

import psycopg2
import json
from routes.exceptions import RouteSearchError, RouteNotFoundError
from utils.coverage import check_within_coverage
from utils.db_errors import parse_pg_error_code, parse_pg_error_message


class RouteRepository:
    def __init__(self, conn):
        self.connection = conn

    def get_coverage(self):
        try:
            with self.connection.cursor()as cursor:
                cursor.execute("""
                    SELECT ST_AsGeoJSON(bbox) FROM graph_coverage LIMIT 1
                    """)
                raw = cursor.fetchone()[0]
                if raw is None:
                    raise RouteSearchError("graph_coverage is empty")
                result = json.loads(raw)
                return result
        except psycopg2.Error as e:
            raise RouteSearchError(e.pgerror) from e


    def find_route(self, lat_start: float, lon_start: float, lat_end: float, lon_end: float, speed_kmh: float):
        check_within_coverage(self.connection, lat_start, lon_start)
        check_within_coverage(self.connection, lat_end, lon_end)
        try:
            with self.connection.cursor() as cursor:
                cursor.execute("""
                    SELECT
                        export_route_api(%s, %s, %s, %s, %s)
                """,
                (lat_start, lon_start, lat_end, lon_end, speed_kmh))
                result = cursor.fetchone()[0]
                return result
        except psycopg2.Error as e:
            # Expected error: clean, user-facing message. Unexpected: full pgerror for the logs
            message = e.diag.message_primary
            if parse_pg_error_code(message) == 'ROUTING:NO_PATH':
                raise RouteNotFoundError(parse_pg_error_message(message)) from e
            raise RouteSearchError(e.pgerror) from e

