# exceptions.py — custom exceptions for the POI service
# Layer : Exception
# Defines domain-specific errors : invalid category, invalid radius, database error.

class InvalidCategoryError(Exception):
    pass

class InvalidRadiusError(Exception):
    pass

class POISearchError(Exception):
    pass

class POIRouteNotFoundError(Exception):
    pass