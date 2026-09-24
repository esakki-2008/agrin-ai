import asyncio
import json
import time
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(
    prefix="/agent",
    tags=["intelligence-agent"],
)


class AgentRequest(BaseModel):
    location: str = Field(..., min_length=1, max_length=120)
    crop: str = Field(..., min_length=1, max_length=80)
    farm_size_acres: float | None = Field(
        default=None,
        gt=0,
        le=100000,
    )
    historical_days: int = Field(
        default=30,
        ge=7,
        le=92,
    )


# ============================================================
# LOCATION
# ============================================================

async def geocode(location: str):
    from data_sources import _get_http_client

    client = await _get_http_client()

    # --------------------------------------------------------
    # PRIMARY: OPEN-METEO
    # --------------------------------------------------------

    # Try increasingly specific queries so short Indian place names
    # are resolved consistently by Open-Meteo.
    geocode_queries = [
        location.strip(),
        f"{location.strip()}, Maharashtra, India",
        f"{location.strip()}, India",
    ]

    for query in geocode_queries:
        try:
            response = await client.get(
                "https://geocoding-api.open-meteo.com/v1/search",
                params={
                    "name": query,
                    "count": 5,
                    "language": "en",
                    "format": "json",
                },
                timeout=10,
            )

            if response.status_code == 200:
                results = response.json().get("results") or []

                # Prefer India/Maharashtra when multiple matches exist.
                ranked = sorted(
                    results,
                    key=lambda item: (
                        0
                        if str(item.get("country_code", "")).upper() == "IN"
                        else 1,
                        0
                        if "Maharashtra" in str(item.get("admin1", ""))
                        else 1,
                    ),
                )

                if ranked:
                    item = ranked[0]

                    return {
                        "name": item.get("name"),
                        "admin1": item.get("admin1"),
                        "country": item.get("country"),
                        "latitude": item["latitude"],
                        "longitude": item["longitude"],
                    }

        except (
            httpx.HTTPError,
            ValueError,
            KeyError,
            TypeError,
        ):
            continue

    # --------------------------------------------------------
    # FALLBACK: KNOWN INDIAN LOCATIONS
    # --------------------------------------------------------

    # Keep the production Agent usable even when public geocoding
    # providers are unavailable. These are geographic coordinates,
    # not user/device location data.
    known_locations = {
        "dombivli": {
            "name": "Dombivli",
            "admin1": "Maharashtra",
            "country": "India",
            "latitude": 19.2183,
            "longitude": 73.0865,
        },
        "dombivli east": {
            "name": "Dombivli East",
            "admin1": "Maharashtra",
            "country": "India",
            "latitude": 19.2183,
            "longitude": 73.0865,
        },
    }

    known = known_locations.get(location.strip().lower())
    if known:
        return known

    # Final generic Nominatim fallback for other locations.
    queries = [location.strip()]
    if "," not in location:
        queries.append(f"{location.strip()}, India")

    for query in queries:
        try:
            response = await client.get(
                "https://nominatim.openstreetmap.org/search",
                params={
                    "q": query,
                    "format": "jsonv2",
                    "limit": 1,
                    "addressdetails": 1,
                },
                headers={
                    "User-Agent": (
                        "AgriN-AI/1.0 "
                        "(https://github.com/esakki-2008/agrin-ai)"
                    ),
                },
                timeout=10,
            )

            if response.status_code == 200:
                results = response.json()

                if results:
                    item = results[0]
                    address = item.get("address") or {}

                    return {
                        "name": item.get("display_name"),
                        "admin1": (
                            address.get("state")
                            or address.get("state_district")
                        ),
                        "country": address.get("country"),
                        "latitude": float(item["lat"]),
                        "longitude": float(item["lon"]),
                    }

        except (
            httpx.HTTPError,
            ValueError,
            KeyError,
            TypeError,
        ):
            continue

    raise HTTPException(
        status_code=404,
        detail=f"No location found for '{location}'.",
    )


# ============================================================
# WEATHER
# ============================================================

async def weather(lat: float, lon: float):
    from data_sources import _get_http_client

    params = {
        "latitude": lat,
        "longitude": lon,
        "current": (
            "temperature_2m,"
            "relative_humidity_2m,"
            "precipitation,"
            "weather_code,"
            "wind_speed_10m"
        ),
        "hourly": "precipitation_probability",
        "forecast_days": 1,
        "timezone": "auto",
    }

    client = await _get_http_client()

    # --------------------------------------------------------
    # PRIMARY: OPEN-METEO
    # --------------------------------------------------------

    try:
        response = await client.get(
            "https://api.open-meteo.com/v1/forecast",
            params=params,
            timeout=20,
        )

        if response.status_code == 200:
            body = response.json()

            current = body.get("current", {})

            probabilities = (
                body.get("hourly", {})
                .get("precipitation_probability", [])
            )

            rain_probability = (
                probabilities[0]
                if probabilities
                else None
            )

            return {
                "source": "Open-Meteo",
                "temperature_c": current.get(
                    "temperature_2m"
                ),
                "humidity_percent": current.get(
                    "relative_humidity_2m"
                ),
                "precipitation_mm": current.get(
                    "precipitation"
                ),
                "weather_code": current.get(
                    "weather_code"
                ),
                "wind_speed_kmh": current.get(
                    "wind_speed_10m"
                ),
                "rain_probability_percent": rain_probability,
                "observed_at": current.get("time"),
            }

    except (
        httpx.HTTPError,
        ValueError,
        KeyError,
        TypeError,
    ):
        pass

    # --------------------------------------------------------
    # FALLBACK: MET NORWAY
    # --------------------------------------------------------

    try:
        response = await client.get(
            "https://api.met.no/weatherapi/locationforecast/2.0/compact",
            params={
                "lat": round(lat, 4),
                "lon": round(lon, 4),
            },
            headers={
                "User-Agent": (
                    "AgriN-AI/1.0 "
                    "(https://github.com/esakki-2008/agrin-ai)"
                ),
            },
            timeout=20,
        )

        if response.status_code == 200:
            body = response.json()

            timeseries = (
                body.get("properties", {})
                .get("timeseries", [])
            )

            if timeseries:
                current = timeseries[0]

                instant = (
                    current.get("data", {})
                    .get("instant", {})
                    .get("details", {})
                )

                next_hour = (
                    current.get("data", {})
                    .get("next_1_hours", {})
                    .get("details", {})
                )

                temperature = instant.get(
                    "air_temperature"
                )

                humidity = instant.get(
                    "relative_humidity"
                )

                wind_speed_ms = instant.get(
                    "wind_speed"
                )

                precipitation = next_hour.get(
                    "precipitation_amount"
                )

                rain_probability = next_hour.get(
                    "probability_of_precipitation"
                )

                return {
                    "source": (
                        "MET Norway Locationforecast"
                    ),
                    "temperature_c": temperature,
                    "humidity_percent": humidity,
                    "precipitation_mm": precipitation,
                    "weather_code": None,
                    "wind_speed_kmh": (
                        wind_speed_ms * 3.6
                        if wind_speed_ms is not None
                        else None
                    ),
                    "rain_probability_percent": (
                        rain_probability
                    ),
                    "observed_at": current.get(
                        "time"
                    ),
                }

    except (
        httpx.HTTPError,
        ValueError,
        KeyError,
        TypeError,
    ):
        pass

    raise HTTPException(
        status_code=502,
        detail="Weather service failed.",
    )

# ============================================================
# GEMINI EVIDENCE ENGINE
# ============================================================

async def gemini_report(evidence: dict):
    """
    Generate concise, evidence-grounded agricultural decision support.
    """

    prompt = """You are the AgriN Farm Intelligence Agent.

Use ONLY the supplied EVIDENCE. Do not invent facts, measurements,
soil moisture, irrigation status, crop stage, disease/pests, yield,
fertilizer/pesticide requirements, weather, satellite observations,
field conditions, thresholds, or numeric values.

Evidence rules:
- SoilGrids is model-derived. Report its values as estimates only.
  Do not label pH, organic carbon, nitrogen, or clay as low/high,
  deficient/sufficient/optimal/excessive without a validated range
  explicitly present in EVIDENCE.
- Do not introduce external crop-specific soil ranges.
- Sentinel-2 NDVI is a point/sample observation, not a whole-farm
  health score. Do not infer disease, yield loss, crop failure, or
  crop health from one NDVI value.
- Consider cloud cover when discussing satellite observations.
- Historical weather/NDVI do not establish causality.
- Do not claim rainfall caused NDVI change or humidity caused disease.
- Do not diagnose disease from weather data.
- Missing data stays missing.
- If current satellite data is unavailable, explicitly state:
  "Current suitable satellite observation is unavailable."
- Recommendations are decision-support actions, not guaranteed outcomes.
- When evidence is insufficient, recommend field inspection, lab testing,
  monitoring, or additional data collection instead of guessing.
- Never prescribe pesticide/fertilizer dosage or invent irrigation quantities.

Separate important information into:
OBSERVED = what the source reports.
INTERPRETATION = what the evidence supports.
UNKNOWN = what cannot be established.
ACTION = what should be checked next.

Return ONLY valid JSON using exactly this structure:
{
  "summary": "brief evidence-grounded summary",
  "recommendations": [
    {
      "title": "action",
      "reason": "evidence-based reason",
      "priority": "high|medium|low",
      "evidence": ["specific supplied observation"]
    }
  ],
  "observations": ["important measured/model-derived observations"],
  "next_checks": ["specific field, laboratory, or data check"],
  "limitations": ["important evidence limitation"]
}

Keep the response concise. Preserve source meaning and exact supplied
measurements when mentioning them. Do not silently convert measurements
into agricultural classifications.

EVIDENCE:
""" + json.dumps(evidence, ensure_ascii=False, separators=(",", ":"))

    from ai_gateway import AIProviderError, generate_json

    try:
        result, provider_meta = await generate_json(
            prompt,
            temperature=0.1,
            timeout=25,
        )
    except AIProviderError as exc:
        raise HTTPException(
            status_code=503,
            detail="AI agent service is temporarily unavailable.",
        ) from exc

    return {
        "report": result,
        "provider": provider_meta,
    }


# ============================================================
# AGENT ANALYSIS
# ============================================================

@router.post("/analyze")
async def analyze(request: AgentRequest):
    request_started = time.perf_counter()

    # --------------------------------------------------------
    # VALIDATION
    # --------------------------------------------------------

    if not request.location.strip():
        raise HTTPException(
            status_code=400,
            detail="Location is required.",
        )

    if not request.crop.strip():
        raise HTTPException(
            status_code=400,
            detail="Crop is required.",
        )

    if (
        request.farm_size_acres is not None
        and request.farm_size_acres <= 0
    ):
        raise HTTPException(
            status_code=400,
            detail="Farm size must be positive.",
        )

    if not 7 <= request.historical_days <= 92:
        raise HTTPException(
            status_code=400,
            detail=(
                "historical_days must be between "
                "7 and 92."
            ),
        )

    # --------------------------------------------------------
    # LOCATION
    # --------------------------------------------------------

    geocode_started = time.perf_counter()

    place = await geocode(
        request.location.strip()
    )

    geocode_ms = round((time.perf_counter() - geocode_started) * 1000, 1)

    lat = place["latitude"]
    lon = place["longitude"]

    # --------------------------------------------------------
    # SHARED DATA SOURCES
    # --------------------------------------------------------

    from data_sources import (
        find_satellite_scene,
        sample,
    )

    from historical import (
        HistoricalRequest,
        historical_weather,
        historical_satellite_ndvi,
    )

    async def fetch_soil():
        try:
            ph, organic_carbon, nitrogen, clay = await asyncio.gather(
                sample("phh2o", "phh2o_0-5cm_Q0.5", lon, lat),
                sample("soc", "soc_0-5cm_Q0.5", lon, lat),
                sample("nitrogen", "nitrogen_0-5cm_Q0.5", lon, lat),
                sample("clay", "clay_0-5cm_Q0.5", lon, lat),
            )
            return {
                "source": "ISRIC SoilGrids 2.0",
                "resolution_m": 250,
                "depth": "0-5cm",
                "pH": round(ph / 10, 2),
                "organic_carbon_g_kg": round(organic_carbon / 10, 2),
                "nitrogen_g_kg": round(nitrogen / 100, 3),
                "clay_percent": round(clay / 10, 2),
            }
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(status_code=502, detail="Soil data unavailable.") from exc

    async def fetch_satellite():
        try:
            feature = await find_satellite_scene(lat, lon, 30, 30)
            if feature:
                props = feature.get("properties", {})
                return {
                    "available": True,
                    "source": "Sentinel-2 Collection 1 L2A / AWS Open Data",
                    "scene_id": feature.get("id"),
                    "observation_date": props.get("datetime"),
                    "cloud_cover_percent": props.get("eo:cloud_cover"),
                }
            return {
                "available": False,
                "source": "AWS Open Data / Earth Search STAC",
                "message": "No suitable Sentinel-2 scene was found within the selected cloud threshold.",
            }
        except Exception:
            return {
                "available": False,
                "source": "AWS Open Data / Earth Search STAC",
                "message": "Satellite observation unavailable.",
            }

    async def fetch_historical_weather():
        try:
            return await historical_weather(
                HistoricalRequest(
                    latitude=lat,
                    longitude=lon,
                    days=request.historical_days,
                )
            )
        except Exception:
            return {
                "available": False,
                "message": "Historical weather unavailable.",
            }

    async def fetch_historical_ndvi():
        try:
            return await historical_satellite_ndvi(
                HistoricalRequest(
                    latitude=lat,
                    longitude=lon,
                    days=request.historical_days,
                )
            )
        except Exception:
            return {
                "available": False,
                "message": "Historical satellite observations unavailable.",
            }

    data_started = time.perf_counter()

    weather_data, soil_data, satellite_data, historical_data, historical_ndvi = await asyncio.gather(
        weather(lat, lon),
        fetch_soil(),
        fetch_satellite(),
        fetch_historical_weather(),
        fetch_historical_ndvi(),
    )

    data_ms = round((time.perf_counter() - data_started) * 1000, 1)

    # --------------------------------------------------------
    # EVIDENCE PACK
    # --------------------------------------------------------

    evidence = {
        "location": {
            "requested": request.location,
            "resolved": place,
        },

        "crop": request.crop,

        "farm_size_acres": (
            request.farm_size_acres
        ),

        "weather": weather_data,

        "soil": soil_data,

        "satellite": satellite_data,

        "historical_weather": historical_data,

        "historical_ndvi": historical_ndvi,
    }

    # --------------------------------------------------------
    # AI REASONING
    # --------------------------------------------------------

    gemini_started = time.perf_counter()

    report = await gemini_report(
        evidence
    )

    gemini_ms = round((time.perf_counter() - gemini_started) * 1000, 1)
    total_ms = round((time.perf_counter() - request_started) * 1000, 1)

    print(
        json.dumps(
            {
                "event": "agent_timing",
                "geocode_ms": geocode_ms,
                "data_ms": data_ms,
                "gemini_ms": gemini_ms,
                "total_ms": total_ms,
            },
            separators=(",", ":"),
        )
    )

    # --------------------------------------------------------
    # RESPONSE
    # --------------------------------------------------------

    return {
        "agent": (
            "AgriN Farm Intelligence Agent"
        ),

        "version": "1.1",

        "generated_at": (
            datetime.now(
                timezone.utc
            ).isoformat()
        ),

        "evidence": evidence,

        "report": report,

        "sources": [
            "Open-Meteo",
            "ISRIC SoilGrids 2.0",
            (
                "Sentinel-2 Collection 1 L2A / "
                "AWS Open Data"
            ),
            "AgriN historical intelligence services",
            "Google Gemini API",
        ],
    }
