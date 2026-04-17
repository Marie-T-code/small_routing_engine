from dataclasses import dataclass
from pois.enums import POICategory
from pois.models import POI
from pois.exceptions import InvalidCategoryError, InvalidRadiusError


@dataclass
class POISearchRequest:
    lat_start: float
    lon_start: float
    lat_end: float
    lon_end: float
    category: POICategory
    radius_m: float
    def validate (self): 
        if self.radius_m <= 10 or self.radius_m > 1000:
            raise InvalidRadiusError("Invalid radius, please choose a value between 10 and 1000 meters")
        if self.category not in POICategory:
            raise InvalidCategoryError("Invalid category detected, please choose a valid category")

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