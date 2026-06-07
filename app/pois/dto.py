# dto.py — data transfer objects for the POI service
# Layer : DTO
# Defines POISearchRequest (input validation) and POISearchResponse (GeoJSON output).

from dataclasses import dataclass
from pois.enums import POICategory
from pois.models import POI
from pois.exceptions import InvalidRadiusError
from utils.exceptions import SamePointError  


@dataclass
class POISearchRequest:
    lat_start: float
    lon_start: float
    lat_end: float
    lon_end: float
    category: POICategory
    radius_m: float
    def validate (self): 
        # category is validated + converted at the blueprint layer (fail-fast, pre-DB).
        # DTO owns business rules: identical points, then radius bounds.
        if (self.lat_start, self.lon_start) == (self.lat_end, self.lon_end):
            raise SamePointError("Start and end points must differ")
        if self.radius_m <= 10 or self.radius_m > 1000:
            raise InvalidRadiusError("Invalid radius, please choose a value between 10 and 1000 meters")

@dataclass
class POISearchResponse:
    pois: list[POI]

    def to_geojson(self) -> dict:
        return{
            "type": "FeatureCollection", 
            "features": [{
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [poi.lon, poi.lat]
                    },
                "properties": {
                    "name": poi.name, 
                    "amenity": poi.amenity,
                    "category": poi.category.value,
                    "distance_m": poi.distance_m
                    }
            }
            for poi in self.pois  
            ]
        }