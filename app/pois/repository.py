from psycopg2 import _psycopg
from pois.models import POI
from pois.enums import POICategory
from pois.exceptions import POISearchError

class POIRepository:
    def __init__(self,connection):
        self.conn = connection

def find_pois_along_route(self,lat_start: float, lon_start: float, lat_end: float, lon_end: float, radius_m: float, category: POICategory)-> list[POI]:
    with self.connection.cursor() as cursor:
        cursor.execute(
            SELECT
                p.name,
                p.amenity, 
                p.category, 
                ST_X(p.geom) AS lon,
                ST_Y(P.geom) AS lat,
                ST_Distance(p.geom, r.route_geom_graph)
            (parametres,))
        rows = cursor.fetchall()