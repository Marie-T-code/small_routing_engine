# repository.py — database access layer for the Route service
# Layer : Repository
# Queries PostGIS (export_api_route_feature_api()) to compute a route.

import psycopg2
from routes.exceptions import RouteSearchError, RouteNotFoundError

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
                if result is None:
                    raise RouteNotFoundError("No path between selected points")
                return result
        except psycopg2.Error as e:
            raise RouteSearchError("Database Error") from e
        