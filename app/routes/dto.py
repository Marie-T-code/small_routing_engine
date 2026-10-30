# dto.py —  data transfer objects for the route service
#layer: DTO
# defines RouteSearchRequest (input validation) and RouteResponse (Wraps SQL GeoJSON output)
# No use for a "model" module yet as the Database returns the geojson

import math
from dataclasses import dataclass

from routes.exceptions import InvalidCoordinatesError, InvalidSpeedError
from utils.exceptions import SamePointError


@dataclass
class RouteSearchRequest:
    lat_start: float
    lon_start: float
    lat_end: float
    lon_end: float
    speed_kmh: float

    def __post_init__(self):
        coords = {
            "lat_start": self.lat_start,
            "lon_start": self.lon_start,
            "lat_end": self.lat_end,
            "lon_end": self.lon_end
        }
        invalid = [name for name, value in coords.items() if not math.isfinite(value)]
        if invalid:
            raise InvalidCoordinatesError(f"Coordinates must be finite numbers: {invalid}")
        # reject identical start/end before hitting the engine
        if (self.lat_start, self.lon_start) == (self.lat_end, self.lon_end):
            raise SamePointError("Start and end points must differ")
        if not (10 <= self.speed_kmh <= 25):
            raise InvalidSpeedError(
                f"Invalid speed: {self.speed_kmh}. Expected between 10 and 25 km/h")


@dataclass
class RouteResponse:
    result: dict
