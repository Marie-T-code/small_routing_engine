# exceptions.py — custom exceptions for the POI service
# Layer : Exception
# Expected errors inherit from ClientError (carry their HTTP status).
# POISearchError is unexpected (DB failure) and stays a plain Exception -> 500.

from utils.exceptions import ClientError


class InvalidCategoryError(ClientError):
    pass


class InvalidRadiusError(ClientError):
    pass


class POIRouteNotFoundError(ClientError):
    status_code = 404


class POISearchError(Exception):
    pass
