from datetime import date, datetime, timedelta, timezone

import asyncio
import httpx
from data_sources import _get_http_client
import rasterio
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

_weather_cache: dict[tuple[float, float, int], tuple[datetime, dict]] = {}
_WEATHER_CACHE_TTL = timedelta(minutes=10)

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

    cache_key = (round(request.latitude, 4), round(request.longitude, 4), request.days)
    cached = _weather_cache.get(cache_key)
    now_utc = datetime.now(timezone.utc)
    if cached and now_utc - cached[0] < _WEATHER_CACHE_TTL:
        return cached[1]

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

    result = {
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
    _weather_cache[cache_key] = (now_utc, result)
    return result


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
        client = await _get_http_client()
        response = await client.post(
            "https://earth-search.aws.element84.com/v1/search",
            json=payload,
            timeout=30,
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


@router.post("/satellite-ndvi")
async def historical_satellite_ndvi(request: HistoricalRequest):
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
        raise HTTPException(status_code=502, detail=f"Historical satellite catalog returned HTTP {response.status_code}.")

    features = response.json().get("features", [])
    candidates = []
    for feature in features:
        cloud = feature.get("properties", {}).get("eo:cloud_cover")
        if cloud is not None and float(cloud) <= 60:
            candidates.append(feature)

    candidates.sort(
        key=lambda feature: feature.get("properties", {}).get("datetime") or "",
        reverse=True,
    )
    candidates = candidates[:8]

    client = await _get_http_client()

    async def process_scene(feature):
        item_id = feature.get("id")
        item_url = f"https://earth-search.aws.element84.com/v1/collections/sentinel-2-c1-l2a/items/{item_id}"
        try:
        item_response = await client.get(item_url, timeout=45)
            if item_response.status_code != 200:
                continue
            item = item_response.json()
            assets = item.get("assets", {})
            red_asset = assets.get("red")
            nir_asset = assets.get("nir")
            if not red_asset or not nir_asset:
                continue
             red_href = red_asset.get("href")
            nir_href = nir_asset.get("href")
            if not red_href or not nir_href:
                continue
             def read_reflectance(href: str, asset: dict) -> float:
                with rasterio.open(href) as dataset:
                    from rasterio.warp import transform
                    xs, ys = transform(
                        "EPSG:4326",
                        dataset.crs,
                        [request.longitude],
                        [request.latitude],
                    )
                    row, col = dataset.index(xs[0], ys[0])
                    half = 2
                    window = rasterio.windows.Window(
                        max(0, col - half),
                        max(0, row - half),
                        5,
                        5,
                    )
                    values = dataset.read(1, window=window, masked=True).astype("float64")
                    valid = values.compressed()
                    valid = valid[valid >= 0]
                    if len(valid) == 0:
                        raise ValueError("No valid pixels.")
                    bands = asset.get("raster:bands", [])
                    scale = (bands[0].get("scale", 1.0) or 1.0) if bands else 1.0
                    offset = (bands[0].get("offset", 0.0) or 0.0) if bands else 0.0
                    return float((valid * scale + offset).mean())
             red = read_reflectance(red_href, red_asset)
            nir = read_reflectance(nir_href, nir_asset)
            denominator = nir + red
            if denominator == 0:
                continue
             ndvi = max(-1.0, min(1.0, (nir - red) / denominator))
            properties = feature.get("properties", {})
            observations.append({
                "scene_id": item_id,
                "date": properties.get("datetime"),
                "cloud_cover_percent": round(float(properties.get("eo:cloud_cover")), 2),
                "red_reflectance": round(red, 6),
                "nir_reflectance": round(nir, 6),
                "ndvi": round(ndvi, 6),
            })
        except Exception:
            continue

    observations = [item for result in await asyncio.gather(*(process_scene(feature) for feature in candidates)) for item in result]
    observations.sort(key=lambda x: x.get("date") or "")
    return {
        "available": len(observations) > 0,
        "source": "Sentinel-2 Collection 1 L2A / AWS Open Data",
        "collection": "sentinel-2-c1-l2a",
        "coordinates": {"latitude": request.latitude, "longitude": request.longitude},
        "days": request.days,
        "max_cloud_cover_used_percent": 60,
        "count": len(observations),
        "observations": observations,
        "message": None if observations else "No usable Sentinel-2 NDVI observations were available for this period and cloud threshold.",
    }
