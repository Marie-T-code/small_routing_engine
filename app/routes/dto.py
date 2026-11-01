# dto.py —  data transfer objects for the route service
# layer: DTO
# defines RouteSearchRequest (input validation) and RouteResponse (Wraps SQL GeoJSON output)
# No use for a "model" module yet as the Database returns the geojson

from dataclasses import dataclass

from routes.exceptions import InvalidSpeedError
from utils.validation import check_endpoints


@dataclass
class RouteSearchRequest:
    lat_start: float
    lon_start: float
    lat_end: float
    lon_end: float
    speed_kmh: float

    def __post_init__(self):
        check_endpoints(self.lat_start, self.lon_start, self.lat_end, self.lon_end)
        if not (10 <= self.speed_kmh <= 25):
            raise InvalidSpeedError(
                f"Invalid speed: {self.speed_kmh}. Expected between 10 and 25 km/h")


@dataclass
class RouteResponse:
    result: dict
