import json
import os
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/agent", tags=["intelligence-agent"])


class AgentRequest(BaseModel):
    location: str
    crop: str
    farm_size_acres: float | None = None
    historical_days: int = 30


async def geocode(location: str):
    async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
        response = await client.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={"name": location, "count": 1, "language": "en", "format": "json"},
        )
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail="Location geocoding failed.")
    results = response.json().get("results") or []
    if not results:
        raise HTTPException(status_code=404, detail=f"No location found for '{location}'.")
    item = results[0]
    return {
        "name": item.get("name"),
        "admin1": item.get("admin1"),
        "country": item.get("country"),
        "latitude": item["latitude"],
        "longitude": item["longitude"],
    }


async def weather(lat: float, lon: float):
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m",
        "hourly": "precipitation_probability",
        "forecast_days": 1,
        "timezone": "auto",
    }
    async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
        response = await client.get("https://api.open-meteo.com/v1/forecast", params=params)
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail="Weather service failed.")
    body = response.json()
    current = body.get("current", {})
    probabilities = body.get("hourly", {}).get("precipitation_probability", [])
    rain_probability = probabilities[0] if probabilities else None
    return {
        "source": "Open-Meteo",
        "temperature_c": current.get("temperature_2m"),
        "humidity_percent": current.get("relative_humidity_2m"),
        "precipitation_mm": current.get("precipitation"),
        "weather_code": current.get("weather_code"),
        "wind_speed_kmh": current.get("wind_speed_10m"),
        "rain_probability_percent": rain_probability,
        "observed_at": current.get("time"),
    }


async def gemini_report(evidence: dict):
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="GEMINI_API_KEY is not configured on the backend.")

    prompt = """You are the AgriN Farm Intelligence Agent.
Reason ONLY from the supplied observations. Never invent measurements, crop stage, disease,
soil moisture, irrigation status, weather conditions, or satellite observations.

Create an evidence-grounded agricultural decision report. Recommendations must be framed as
decision support, not guaranteed outcomes. For every recommendation, cite the supplied evidence
source(s). If evidence is insufficient, explicitly say so.

Return ONLY valid JSON:
{
  "summary": "short overall evidence-grounded summary",
  "recommendations": [
    {
      "title": "action",
      "reason": "why, based only on supplied evidence",
      "priority": "high|medium|low",
      "evidence": ["source or observation"]
    }
  ],
  "observations": ["important measured/model observations"],
  "next_checks": ["specific field or data checks"],
  "limitations": ["important evidence limitations"]
}

Important: SoilGrids is model-derived. Sentinel-2 NDVI here is a point/sample observation,
not a whole-farm health score. Do not infer causality from historical weather and NDVI.

EVIDENCE:
""" + json.dumps(evidence, ensure_ascii=False)

    endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.15, "responseMimeType": "application/json"},
    }
    response = None
    last_error = None
    for attempt in range(3):
        try:
            async with httpx.AsyncClient(timeout=60, follow_redirects=True) as client:
                response = await client.post(
                    endpoint,
                    headers={"x-goog-api-key": api_key, "Content-Type": "application/json"},
                    json=payload,
                )
        except httpx.HTTPError as exc:
            last_error = f"Gemini request failed: {exc}"
            response = None

        if response is not None and response.status_code == 200:
            break

        # Gemini can temporarily return 429/503 during demand spikes.
        # Retry briefly before surfacing the real provider error to the UI.
        if response is None or response.status_code in (429, 500, 502, 503, 504):
            if attempt < 2:
                import asyncio
                await asyncio.sleep(2 ** attempt)
                continue

        break

    if response is None:
        raise HTTPException(status_code=502, detail=last_error or "Gemini request failed.")

    if response.status_code != 200:
        detail = "Gemini API request failed."
        try:
            detail = response.json().get("error", {}).get("message", detail)
        except ValueError:
            pass
        raise HTTPException(status_code=502, detail=detail)

    try:
        body = response.json()
        text = body["candidates"][0]["content"]["parts"][0]["text"]
        return json.loads(text)
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Gemini returned an invalid agent response.") from exc


@router.post("/analyze")
async def analyze(request: AgentRequest):
    if not request.location.strip():
        raise HTTPException(status_code=400, detail="Location is required.")
    if not request.crop.strip():
        raise HTTPException(status_code=400, detail="Crop is required.")
    if request.farm_size_acres is not None and request.farm_size_acres <= 0:
        raise HTTPException(status_code=400, detail="Farm size must be positive.")
    if not 7 <= request.historical_days <= 92:
        raise HTTPException(status_code=400, detail="historical_days must be between 7 and 92.")

    place = await geocode(request.location.strip())
    lat, lon = place["latitude"], place["longitude"]

    from main import find_satellite_scene, sample
    from historical import HistoricalRequest, historical_weather, historical_satellite_ndvi

    weather_data = await weather(lat, lon)

    soil_data = {
        "source": "ISRIC SoilGrids 2.0",
        "resolution_m": 250,
        "depth": "0-5cm",
        "pH": round((await sample("phh2o", "phh2o_0-5cm_Q0.5", lon, lat)) / 10, 2),
        "organic_carbon_g_kg": round((await sample("soc", "soc_0-5cm_Q0.5", lon, lat)) / 10, 2),
        "nitrogen_g_kg": round((await sample("nitrogen", "nitrogen_0-5cm_Q0.5", lon, lat)) / 100, 3),
        "clay_percent": round((await sample("clay", "clay_0-5cm_Q0.5", lon, lat)) / 10, 2),
    }

    satellite_data = None
    try:
        feature = await find_satellite_scene(lat, lon, 30, 30)
        if feature:
            props = feature.get("properties", {})
            satellite_data = {
                "available": True,
                "source": "Sentinel-2 Collection 1 L2A / AWS Open Data",
                "scene_id": feature.get("id"),
                "observation_date": props.get("datetime"),
                "cloud_cover_percent": props.get("eo:cloud_cover"),
            }
        else:
            satellite_data = {
                "available": False,
                "source": "AWS Open Data / Earth Search STAC",
                "message": "No suitable Sentinel-2 scene was found within the selected cloud threshold.",
            }
    except Exception as exc:
        satellite_data = {
            "available": False,
            "source": "AWS Open Data / Earth Search STAC",
            "message": f"Satellite observation unavailable: {exc}",
        }

    historical_data = None
    try:
        historical_data = await historical_weather(
            HistoricalRequest(latitude=lat, longitude=lon, days=request.historical_days)
        )
    except Exception as exc:
        historical_data = {"available": False, "message": f"Historical weather unavailable: {exc}"}

    historical_ndvi = None
    try:
        historical_ndvi = await historical_satellite_ndvi(
            HistoricalRequest(latitude=lat, longitude=lon, days=request.historical_days)
        )
    except Exception as exc:
        historical_ndvi = {"available": False, "message": f"Historical satellite observations unavailable: {exc}"}

    evidence = {
        "location": {
            "requested": request.location,
            "resolved": place,
        },
        "crop": request.crop,
        "farm_size_acres": request.farm_size_acres,
        "weather": weather_data,
        "soil": soil_data,
        "satellite": satellite_data,
        "historical_weather": historical_data,
        "historical_ndvi": historical_ndvi,
    }

    report = await gemini_report(evidence)

    return {
        "agent": "AgriN Farm Intelligence Agent",
        "version": "1.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "evidence": evidence,
        "report": report,
        "sources": [
            "Open-Meteo",
            "ISRIC SoilGrids 2.0",
            "Sentinel-2 Collection 1 L2A / AWS Open Data",
            "AgriN historical intelligence services",
            "Google Gemini API",
        ],
    }
