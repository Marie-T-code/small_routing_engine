# dto.py —  data transfer objects for the route service
#layer : DTO
# defines RouteSearchRequest (input validation) and RouteResponse (Wraps SQL GeoJSON output)
# No use for a "model" module yet as the Database returns the geojson

from dataclasses import dataclass
from routes.exceptions import InvalidCoordinatesError, InvalidSpeedError

@dataclass
class RouteSearchRequest:
    lat_start: float
    lon_start: float
    lat_end: float
    lon_end: float
    speed_kmh: float


    def validate(self): 
        coords = {
            "lat_start": self.lat_start,
            "lon_start": self.lon_start,
            "lat_end": self.lat_end,
            "lon_end": self.lon_end
        }
        missing = [name for name, value in coords.items() if value is None]
        if missing:
            raise InvalidCoordinatesError(f"Missing Coordinates {missing}")
        if self.speed_kmh is None:
            raise InvalidSpeedError("No speed detected, please choose a speed per hour")
        if self.speed_kmh <= 10 or self.speed_kmh > 25:
            raise InvalidSpeedError(f"Invalid speed: {self.speed_kmh}. Expected between 10 and 25 kmh")

@dataclass
class RouteResponse:
    result: dict