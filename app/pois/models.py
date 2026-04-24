# models.py — domain model for the POI service
# Layer : Model
# Defines the POI dataclass — represents a single point of interest returned by the database.

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