# enums.py — valid categories for POI search
# Layer : Enum
# Defines POICategory — used for input validation and database filtering.

from enum import Enum

class POICategory(Enum):
    BIKE = "bike"
    CULTURE = "culture"
    SERVICES = "services"
    CATERING = "catering"