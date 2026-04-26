# repository.py — database access layer for the Route service
# Layer : Repository
# Queries PostGIS (export_api_route_feature_api()) to compute a route.

import psycopg2
from routes.exceptions import RouteSearchError, RouteNotFoundError
from utils.db_errors import parse_pg_error_code

class RouteRepository:
    def __init__(self, conn):
        self.connection = conn

    def find_route(self, lat_start: float, lon_start: float, lat_end: float, lon_end: float, speed_kmh: float):
        try:
            with self.connection.cursor() as cursor:
                cursor.execute("""
                    SELECT
                        export_api_route_feature_api(%s, %s, %s, %s, %s)
                """,
                (lat_start, lon_start, lat_end, lon_end, speed_kmh))
                result = cursor.fetchone()[0]
                return result
        except psycopg2.Error as e:
            code = parse_pg_error_code(e)
            if code == 'ROUTING:NO_PATH':
                raise RouteNotFoundError(e.pgerror) from e
            raise RouteSearchError(e.pgerror) from e
