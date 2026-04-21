from pois.repository import POIRepository
from pois.dto import POISearchRequest, POISearchResponse

class POIService:
    def __init__(self, repository: POIRepository):
        self.repository = repository

    def search(self, request: POISearchRequest):
        request.validate()
        pois = self.repository.find_pois_along_route(request.lat_start, request.lon_start, request.lat_end, request.lon_end, request.radius_m, request.category)
        return POISearchResponse(pois=pois)
        