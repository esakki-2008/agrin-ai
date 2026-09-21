from datetime import date, datetime, timedelta, timezone

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/historical", tags=["historical"])


class HistoricalRequest(BaseModel):
    latitude: float
    longitude: float
    days: int = 30


def _validate(request: HistoricalRequest) -> None:
    if not (-90 <= request.latitude <= 90 and -180 <= request.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")
    if not (7 <= request.days <= 92):
        raise HTTPException(status_code=400, detail="days must be between 7 and 92.")


@router.post("/weather")
async def historical_weather(request: HistoricalRequest):
    _validate(request)

    end = date.today() - timedelta(days=1)
    start = end - timedelta(days=request.days - 1)

    params = {
        "latitude": request.latitude,
        "longitude": request.longitude,
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "daily": "temperature_2m_mean,precipitation_sum,et0_fao_evapotranspiration",
        "timezone": "auto",
    }

    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            response = await client.get(
                "https://archive-api.open-meteo.com/v1/archive",
                params=params,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Historical weather request failed: {exc}") from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Historical weather service returned HTTP {response.status_code}.",
        )

    try:
        body = response.json()
        daily = body["daily"]
        dates = daily["time"]
        temperatures = daily["temperature_2m_mean"]
        precipitation = daily["precipitation_sum"]
        et0 = daily["et0_fao_evapotranspiration"]
    except (KeyError, TypeError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Historical weather returned an invalid response.") from exc

    rows = []
    for i, day in enumerate(dates):
        rows.append({
            "date": day,
            "temperature_mean_c": temperatures[i],
            "precipitation_mm": precipitation[i],
            "et0_mm": et0[i],
        })

    valid_temp = [r["temperature_mean_c"] for r in rows if r["temperature_mean_c"] is not None]
    valid_rain = [r["precipitation_mm"] for r in rows if r["precipitation_mm"] is not None]
    valid_et0 = [r["et0_mm"] for r in rows if r["et0_mm"] is not None]

    mid = len(rows) // 2
    first = rows[:mid]
    second = rows[mid:]

    def avg(items, key):
        values = [x[key] for x in items if x[key] is not None]
        return round(sum(values) / len(values), 2) if values else None

    first_temp = avg(first, "temperature_mean_c")
    second_temp = avg(second, "temperature_mean_c")

    if first_temp is None or second_temp is None:
        temperature_trend = "Unavailable"
    elif second_temp - first_temp >= 1:
        temperature_trend = "Warming"
    elif second_temp - first_temp <= -1:
        temperature_trend = "Cooling"
    else:
        temperature_trend = "Relatively stable"

    return {
        "available": True,
        "source": "Open-Meteo Historical Weather API",
        "period": {"start": start.isoformat(), "end": end.isoformat(), "days": len(rows)},
        "coordinates": {"latitude": request.latitude, "longitude": request.longitude},
        "summary": {
            "average_temperature_c": round(sum(valid_temp) / len(valid_temp), 2) if valid_temp else None,
            "total_precipitation_mm": round(sum(valid_rain), 2) if valid_rain else None,
            "average_daily_et0_mm": round(sum(valid_et0) / len(valid_et0), 2) if valid_et0 else None,
            "temperature_trend": temperature_trend,
        },
        "daily": rows,
    }


@router.post("/satellite-scenes")
async def historical_satellite_scenes(request: HistoricalRequest):
    _validate(request)

    now = datetime.now(timezone.utc)
    start = now - timedelta(days=request.days)

    payload = {
        "collections": ["sentinel-2-c1-l2a"],
        "datetime": f"{start.isoformat().replace('+00:00', 'Z')}/{now.isoformat().replace('+00:00', 'Z')}",
        "intersects": {
            "type": "Point",
            "coordinates": [request.longitude, request.latitude],
        },
        "limit": 50,
    }

    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            response = await client.post(
                "https://earth-search.aws.element84.com/v1/search",
                json=payload,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Historical satellite search failed: {exc}") from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Historical satellite catalog returned HTTP {response.status_code}.",
        )

    scenes = []
    for feature in response.json().get("features", []):
        properties = feature.get("properties", {})
        scenes.append({
            "id": feature.get("id"),
            "datetime": properties.get("datetime"),
            "cloud_cover_percent": properties.get("eo:cloud_cover"),
            "collection": feature.get("collection"),
        })

    scenes.sort(key=lambda x: x.get("datetime") or "", reverse=True)

    return {
        "available": True,
        "source": "AWS Open Data / Earth Search STAC",
        "collection": "sentinel-2-c1-l2a",
        "period_days": request.days,
        "coordinates": {"latitude": request.latitude, "longitude": request.longitude},
        "count": len(scenes),
        "scenes": scenes[:20],
    }
