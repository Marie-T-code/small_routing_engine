# service.py — business logic layer for the routes service
# Layer : Service
# Orchestrates input validation and repository call, returns a RouteResponse

from routes.repository import RouteRepository
from routes.dto import RouteSearchRequest, RouteResponse


class RouteService:
    def __init__(self, repository: RouteRepository):
        self.repository = repository

    def search(self, request: RouteSearchRequest) -> RouteResponse:
        route = self.repository.find_route(
            request.lat_start, request.lon_start,
            request.lat_end, request.lon_end,
            request.speed_kmh
            )
        return RouteResponse(result=route)

    def get_coverage(self) -> dict:
        return self.repository.get_coverage()
