# service.py — business logic layer for the routes service
# Layer : Service
# Calls the repository with a validated request, returns a RouteSearchResponse.

from routes.repository import RouteRepository
from routes.dto import RouteSearchRequest, RouteSearchResponse


class RouteService:
    def __init__(self, repository: RouteRepository):
        self.repository = repository

    def search(self, request: RouteSearchRequest) -> RouteSearchResponse:
        route = self.repository.find_route(
            request.lat_start, request.lon_start,
            request.lat_end, request.lon_end,
            request.speed_kmh
            )
        return RouteSearchResponse(result=route)

    def get_coverage(self) -> dict:
        return self.repository.get_coverage()
