from dataclasses import dataclass
from pois.enums import POICategory

@dataclass
class POI:
    name: str | None
    amenity: str
    category: POICategory
    distance_m: float
    lat: float
    lon: float
    fid: int | None = None
    osm_id: str | None = None