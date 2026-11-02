# exceptions.py — custom exceptions for the Routes service
# Layer : Exception
# Expected errors inherit from ClientError (carry their HTTP status).
# RouteSearchError is unexpected (DB failure) and stays a plain Exception -> 500.

from utils.exceptions import ClientError


class RouteNotFoundError(ClientError):
    status_code = 404


class InvalidSpeedError(ClientError):
    pass


class RouteSearchError(Exception):
    pass
