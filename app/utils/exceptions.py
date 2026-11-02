# utils/exceptions.py — cross-service domain exceptions
# Layer : Exception (shared)
# ClientError is the base class for every expected, client-caused error:
# each subclass carries its HTTP status code. Anything else is a 500.


class ClientError(Exception):
    """ Base class for expected error caused by the client's request. """
    status_code = 400


class PointOutOfCoverageError(ClientError):
    status_code = 422


class SamePointError(ClientError):
    pass


class InvalidCoordinatesError(ClientError):
    pass
