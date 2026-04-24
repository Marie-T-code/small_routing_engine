# repository.py — database access layer for the POI service
# Layer : Repository
# Queries PostGIS to find POIs within a given radius along a computed route.

import psycopg2
from pois.models import POI
from pois.enums import POICategory
from pois.exceptions import POISearchError

class POIRepository:
    def __init__(self,conn):
        self.connection = conn

    def find_pois_along_route(self,lat_start: float, lon_start: float, lat_end: float, lon_end: float, radius_m: float, category: POICategory)-> list[POI]:
        try:
            with self.connection.cursor() as cursor:
                cursor.execute("""
                    SELECT
                        p.name,
                        p.amenity, 
                        p.category, 
                        ST_X(ST_Transform (p.geom, 4326)) AS lon,
                        ST_Y(ST_Transform (p.geom, 4326)) AS lat,
                        ST_Distance(p.geom, r.route_geom_graph) AS distance_m
                    FROM public.pois p
                    CROSS JOIN (
                        SELECT route_geom_graph
                        FROM public.route_metrics(%s, %s, %s, %s)
                    ) r
                    WHERE ST_DWithin(p.geom, r.route_geom_graph, %s)
                    AND p.category = %s
                    ORDER BY distance_m""", 
                    (lat_start, lon_start, lat_end, lon_end, radius_m,category.value))
                rows = cursor.fetchall()
        except psycopg2.Error as e:
            raise POISearchError("Database Error") from e
        pois = [
            POI(
                name=row[0], 
                amenity=row[1], 
                category=POICategory(row[2]), 
                distance_m=row[5], 
                lat=row[4],
                lon=row[3],
                )
            for row in rows
        ]
        return pois