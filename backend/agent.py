import json
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

    try:
        response = await client.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={
                "name": location,
                "count": 1,
                "language": "en",
                "format": "json",
            },
        )

        if response.status_code == 200:
            results = response.json().get("results") or []

            if results:
                item = results[0]

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
        pass

    # --------------------------------------------------------
    # FALLBACK: NOMINATIM / OPENSTREETMAP
    # --------------------------------------------------------

    try:
        response = await client.get(
            "https://nominatim.openstreetmap.org/search",
            params={
                "q": location,
                "format": "jsonv2",
                "limit": 1,
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
            results = response.json()

            if results:
                item = results[0]

                return {
                    "name": item.get("display_name"),
                    "admin1": None,
                    "country": None,
                    "latitude": float(item["lat"]),
                    "longitude": float(item["lon"]),
                }

    except (
        httpx.HTTPError,
        ValueError,
        KeyError,
        TypeError,
    ):
        pass

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
    Generate an evidence-grounded agricultural report.

    Critical rule:
    Gemini may interpret supplied evidence, but it must not
    invent measurements, thresholds, diagnoses, crop stages,
    or unsupported classifications.
    """

    prompt = """
You are the AgriN Farm Intelligence Agent.

Your job is to transform supplied agricultural observations into
careful, evidence-grounded decision support.

STRICT DATA RULES
-----------------

1. Use ONLY the information supplied in EVIDENCE.

2. NEVER invent:
   - measurements
   - soil moisture
   - irrigation status
   - crop growth stage
   - disease presence
   - pest presence
   - yield
   - fertilizer requirement
   - pesticide requirement
   - weather observations
   - weather forecasts
   - satellite observations
   - field conditions

3. NEVER create a numeric value that does not appear in EVIDENCE.

4. SoilGrids is MODEL-DERIVED information.

5. SoilGrids values must be reported as measurements/estimates.
   Do NOT classify them as:
   - low
   - high
   - deficient
   - sufficient
   - optimal
   - excessive

   unless an explicit validated reference range is included
   in EVIDENCE.

6. Do NOT introduce external crop-specific soil ranges.

7. Do NOT say that a pH value is suitable or unsuitable unless
   a validated reference range is explicitly supplied.

8. Do NOT say that organic carbon or nitrogen is low/high unless
   a validated reference range is explicitly supplied.

9. Do NOT say that clay percentage is high/low unless a validated
   reference range is explicitly supplied.

10. Sentinel-2 NDVI in this system is a POINT/SAMPLE observation.

11. A point NDVI is NOT a whole-farm health score.

12. Do NOT convert one NDVI observation into claims such as:
    - severe crop stress
    - healthy crop
    - crop failure
    - disease
    - yield loss
    - poor productivity

13. Cloud cover must be considered when discussing satellite
    observations.

14. If NDVI is available with substantial cloud cover, describe
    it as a limited/anomalous observation requiring verification.

15. Historical weather and historical NDVI must NOT be treated
    as proof of causality.

16. Do NOT claim that rainfall caused an NDVI change.

17. Do NOT claim that humidity caused disease.

18. Do NOT diagnose diseases from weather data.

19. Missing data must remain missing.

20. If current satellite data is unavailable, explicitly state:
    "Current suitable satellite observation is unavailable."

21. Recommendations must be framed as decision-support actions,
    not guaranteed outcomes.

22. Recommendations must be directly connected to supplied evidence.

23. When evidence is insufficient, recommend a field observation,
    laboratory test, or additional data collection rather than
    guessing.

EVIDENCE INTERPRETATION
-----------------------

For every important observation, mentally separate:

OBSERVED
- What the source actually measured.

INTERPRETATION
- What can reasonably be said about that measurement.

UNKNOWN
- What the available evidence cannot establish.

ACTION
- What should be checked next.

Example:

If the evidence says:

NDVI = -0.269389
Cloud cover = 55.24%
Sample = one point

Do NOT say:

"The crop has severe stress."

Instead say something similar to:

"The available Sentinel-2 point sample has a negative NDVI,
but the observation has 55.24% cloud cover and represents
only one sampled location. It should not be treated as a
whole-farm crop-health assessment. Field verification and
a clearer satellite observation are appropriate next checks."

If the evidence says:

Soil organic carbon = 9.09 g/kg

Do NOT say:

"Organic carbon is low."

Instead say:

"SoilGrids reports 9.09 g/kg organic carbon for the sampled
0-5 cm layer. This is model-derived information and does not
by itself establish whether the value is adequate for the crop."

If the evidence says:

pH = 7.21

Do NOT say:

"The soil is unsuitable for grapes."

Instead say:

"SoilGrids reports a pH of 7.21 for the sampled 0-5 cm layer.
Crop suitability cannot be determined from this value alone
without an appropriate validated crop-specific reference."

OUTPUT FORMAT
-------------

Return ONLY valid JSON.

Use exactly:

{
  "summary": "short evidence-grounded summary",

  "recommendations": [
    {
      "title": "action",
      "reason": "why this action follows from supplied evidence",
      "priority": "high|medium|low",
      "evidence": [
        "exact evidence field or observation"
      ]
    }
  ],

  "observations": [
    "important measured/model-derived observation"
  ],

  "next_checks": [
    "specific field, laboratory, or data check"
  ],

  "limitations": [
    "important limitation of the evidence"
  ]
}

SUMMARY RULES
-------------

The summary must NOT make unsupported agricultural conclusions.

It should mention:
- what data is actually available
- important data limitations
- what requires verification

OBSERVATION RULES
-----------------

Observations should preserve the source meaning.

Use wording such as:

"Open-Meteo reports..."
"SoilGrids estimates..."
"Sentinel-2 sampled..."
"No suitable current Sentinel-2 scene was available..."

Do not silently convert measurements into classifications.

RECOMMENDATION RULES
--------------------

Recommendations should focus on evidence collection and
practical verification when evidence is limited.

Examples:

- inspect the crop in the field
- collect a laboratory soil sample
- obtain another satellite observation
- monitor upcoming weather
- verify field soil moisture
- inspect drainage
- record crop stage

Do not prescribe chemical pesticide dosage.

Do not prescribe fertilizer dosage.

Do not invent irrigation quantities.

EVIDENCE
--------

""" + json.dumps(
        evidence,
        ensure_ascii=False,
        indent=2,
    )

    from ai_gateway import (
        AIProviderError,
        generate_json,
    )

    try:
        result, provider_meta = await generate_json(
            prompt,
            temperature=0.1,
            timeout=60,
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

    place = await geocode(
        request.location.strip()
    )

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

    # --------------------------------------------------------
    # CURRENT WEATHER
    # --------------------------------------------------------

    weather_data = await weather(
        lat,
        lon,
    )

    # --------------------------------------------------------
    # SOILGRIDS
    # --------------------------------------------------------

    try:
        ph = await sample(
            "phh2o",
            "phh2o_0-5cm_Q0.5",
            lon,
            lat,
        )

        organic_carbon = await sample(
            "soc",
            "soc_0-5cm_Q0.5",
            lon,
            lat,
        )

        nitrogen = await sample(
            "nitrogen",
            "nitrogen_0-5cm_Q0.5",
            lon,
            lat,
        )

        clay = await sample(
            "clay",
            "clay_0-5cm_Q0.5",
            lon,
            lat,
        )

        soil_data = {
            "source": "ISRIC SoilGrids 2.0",
            "resolution_m": 250,
            "depth": "0-5cm",
            "pH": round(
                ph / 10,
                2,
            ),
            "organic_carbon_g_kg": round(
                organic_carbon / 10,
                2,
            ),
            "nitrogen_g_kg": round(
                nitrogen / 100,
                3,
            ),
            "clay_percent": round(
                clay / 10,
                2,
            ),
        }

    except HTTPException:
        raise

    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail="Soil data unavailable.",
        ) from exc

    # --------------------------------------------------------
    # CURRENT SATELLITE
    # --------------------------------------------------------

    satellite_data = None

    try:
        feature = await find_satellite_scene(
            lat,
            lon,
            30,
            30,
        )

        if feature:
            props = feature.get(
                "properties",
                {},
            )

            satellite_data = {
                "available": True,
                "source": (
                    "Sentinel-2 Collection 1 L2A / "
                    "AWS Open Data"
                ),
                "scene_id": feature.get(
                    "id"
                ),
                "observation_date": props.get(
                    "datetime"
                ),
                "cloud_cover_percent": props.get(
                    "eo:cloud_cover"
                ),
            }

        else:
            satellite_data = {
                "available": False,
                "source": (
                    "AWS Open Data / "
                    "Earth Search STAC"
                ),
                "message": (
                    "No suitable Sentinel-2 scene "
                    "was found within the selected "
                    "cloud threshold."
                ),
            }

    except Exception:
        satellite_data = {
            "available": False,
            "source": (
                "AWS Open Data / "
                "Earth Search STAC"
            ),
            "message": "Satellite observation unavailable.",
        }

    # --------------------------------------------------------
    # HISTORICAL WEATHER
    # --------------------------------------------------------

    try:
        historical_data = await historical_weather(
            HistoricalRequest(
                latitude=lat,
                longitude=lon,
                days=request.historical_days,
            )
        )

    except Exception:
        historical_data = {
            "available": False,
            "message": "Historical weather unavailable.",
        }

    # --------------------------------------------------------
    # HISTORICAL NDVI
    # --------------------------------------------------------

    try:
        historical_ndvi = (
            await historical_satellite_ndvi(
                HistoricalRequest(
                    latitude=lat,
                    longitude=lon,
                    days=request.historical_days,
                )
            )
        )

    except Exception:
        historical_ndvi = {
            "available": False,
            "message": (
                "Historical satellite observations "
                "unavailable."
            ),
        }

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

    report = await gemini_report(
        evidence
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
