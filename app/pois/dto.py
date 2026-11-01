# dto.py — data transfer objects for the POI service
# Layer : DTO
# Defines POISearchRequest (input validation) and POISearchResponse (GeoJSON output).

from dataclasses import dataclass
from pois.enums import POICategory
from pois.models import POI
from pois.exceptions import InvalidRadiusError, InvalidCategoryError
from utils.validation import check_endpoints


@dataclass
class POISearchRequest:
    lat_start: float
    lon_start: float
    lat_end: float
    lon_end: float
    category: POICategory
    radius_m: float
    def __post_init__(self):
        try:
            self.category = POICategory(self.category) # raw str accepted, converted in __post_init__
        except ValueError as e:
            valid = ", ".join(c.value for c in POICategory)
            raise InvalidCategoryError(
                f"Invalid category. Expected: {valid}"
            ) from e
        check_endpoints(self.lat_start, self.lon_start, self.lat_end, self.lon_end)
        if not (10 <= self.radius_m <= 1000):
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
                    "distance_m": poi.distance_m,
                    "osm_id": poi.osm_id
                    }
            }
            for poi in self.pois
            ]
        }