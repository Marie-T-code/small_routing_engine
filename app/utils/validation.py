# validation.py — shared input validation for route endpoints
# Layer : DTO (shared helper)

import math

from utils.exceptions import InvalidCoordinatesError, SamePointError


def check_endpoints(lat_start: float, lon_start: float, lat_end: float, lon_end: float) -> None:
    """Raise if a coordinate is not finite, or if start and end are the same point."""
    coords = {
        "lat_start": lat_start,
        "lon_start": lon_start,
        "lat_end": lat_end,
        "lon_end": lon_end,
    }
    Invalid = [name for name, value in coords.items() if not math.isfinite(value)]
    if Invalid:
        raise InvalidCoordinatesError(f"Coordinates must be finite numbers: {Invalid}")
    if (lat_start, lon_start) == (lat_end, lon_end):
        raise SamePointError("Start and end points must differ")
