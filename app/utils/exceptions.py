# utils/exceptions.py — cross-service domain exceptions
# Layer : Exception (shared)
# Exceptions common to several services (routes, pois...).
class PointOutOfCoverageError(Exception):
    pass

class SamePointError(Exception):
    pass