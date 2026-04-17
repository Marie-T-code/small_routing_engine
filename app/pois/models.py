from dataclasses import dataclass
from app.pois.enums import POICategory

@dataclass
class POI:
    fid: int
    osm_id: str
    name: str | None
    amenity: str
    category: POICategory
    distance_m: float
    lat: float
    lon: float