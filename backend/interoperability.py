from datetime import datetime, timezone

from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter(prefix="/interoperability", tags=["interoperability"])


class FarmObservation(BaseModel):
    country_code: str = Field(min_length=2, max_length=3)
    location_name: str
    latitude: float
    longitude: float
    observed_at: str
    weather: dict | None = None
    soil: dict | None = None
    satellite: dict | None = None
    crop: str | None = None


@router.get("/profile")
async def interoperability_profile():
    return {
        "standard": "AgriN Open Agricultural Observation Profile",
        "version": "1.0",
        "format": "JSON",
        "geometry": "WGS84 latitude/longitude",
        "design": [
            "open JSON contract",
            "source attribution for every observation group",
            "machine-readable timestamps",
            "country-neutral country codes",
            "platform-independent exchange",
            "no vendor-specific storage requirement",
        ],
        "observation_groups": ["weather", "soil", "satellite", "crop"],
        "privacy": [
            "No farmer identity is required by this exchange profile.",
            "Share only the minimum farm observation fields needed for interoperability.",
            "Precise farm coordinates can be generalized before external sharing when required by the data-sharing policy.",
        ],
    }


@router.post("/export")
async def export_observation(observation: FarmObservation):
    country = observation.country_code.upper()
    valid_country_code = country.isalpha() and len(country) in (2, 3)
    valid_coordinates = -90 <= observation.latitude <= 90 and -180 <= observation.longitude <= 180
    valid_timestamp = bool(observation.observed_at.strip())
    valid = valid_country_code and valid_coordinates and valid_timestamp

    if not valid:
        return {
            "exported": False,
            "standard": "AgriN Open Agricultural Observation Profile",
            "version": "1.0",
            "reason": "Observation failed country, coordinate, or timestamp validation.",
        }

    data = observation.model_dump()
    data["country_code"] = country
    return {
        "exported": True,
        "standard": "AgriN Open Agricultural Observation Profile",
        "version": "1.0",
        "content_type": "application/json",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "observation": data,
    }


@router.post("/validate")
async def validate_observation(observation: FarmObservation):
    country = observation.country_code.upper()
    valid_country_code = country.isalpha() and len(country) in (2, 3)
    valid_coordinates = (
        -90 <= observation.latitude <= 90
        and -180 <= observation.longitude <= 180
    )

    return {
        "valid": valid_country_code and valid_coordinates,
        "standard": "AgriN Open Agricultural Observation Profile",
        "version": "1.0",
        "validated_at": datetime.now(timezone.utc).isoformat(),
        "checks": {
            "country_code": valid_country_code,
            "coordinates_wgs84": valid_coordinates,
            "timestamp_present": bool(observation.observed_at.strip()),
            "source_attribution_supported": True,
        },
        "data": observation.model_dump(),
    }
