# exceptions.py — custom exceptions for the Routes service
# Layer : Exception
# Defines domain-specific errors : route not found, invalid coordinates, invalid speed, database error

class RouteNotFoundError(Exception):
    pass

class InvalidCoordinatesError(Exception):
    pass

class InvalidSpeedError(Exception):
    pass

class RouteSearchError(Exception):
    pass
