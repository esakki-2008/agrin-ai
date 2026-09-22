from datetime import datetime, timedelta, timezone
from typing import Any

import httpx
import rasterio
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/satellite", tags=["Advanced Satellite Intelligence"])

STAC_URL = "https://earth-search.aws.element84.com/v1/search"
COLLECTION = "sentinel-2-c1-l2a"


class SatelliteIntelligenceRequest(BaseModel):
    latitude: float
    longitude: float
    days: int = 180
    max_cloud_cover: float = 30.0


def _validate(request: SatelliteIntelligenceRequest) -> None:
    if not (-90 <= request.latitude <= 90 and -180 <= request.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")
    if not (1 <= request.days <= 365):
        raise HTTPException(status_code=400, detail="days must be between 1 and 365.")
    if not (0 <= request.max_cloud_cover <= 100):
        raise HTTPException(status_code=400, detail="max_cloud_cover must be between 0 and 100.")


async def _search_features(lat: float, lon: float, days: int) -> list[dict[str, Any]]:
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)
    payload = {
        "collections": [COLLECTION],
        "datetime": f"{start.isoformat().replace('+00:00', 'Z')}/{now.isoformat().replace('+00:00', 'Z')}",
        "intersects": {"type": "Point", "coordinates": [lon, lat]},
        "limit": 100,
    }
    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            response = await client.post(STAC_URL, json=payload)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Satellite catalog request failed: {exc}") from exc

    if response.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Satellite catalog returned HTTP {response.status_code}.")
    try:
        return response.json().get("features", [])
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Satellite catalog returned invalid JSON.") from exc


def _cloud(feature: dict[str, Any]) -> float | None:
    value = feature.get("properties", {}).get("eo:cloud_cover")
    return float(value) if value is not None else None


def _date_key(feature: dict[str, Any]) -> str:
    value = feature.get("properties", {}).get("datetime") or ""
    return value[:10]


def _choose(features: list[dict[str, Any]], max_cloud: float) -> list[dict[str, Any]]:
    usable = [
        f for f in features
        if _cloud(f) is not None and _cloud(f) <= max_cloud
    ]

    def timestamp(feature: dict[str, Any]) -> float:
        value = feature.get("properties", {}).get("datetime") or ""
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
        except ValueError:
            return 0.0

    # Prefer the lowest-cloud observations; when cloud quality is tied,
    # prefer the newest observation.
    usable.sort(
        key=lambda f: (
            _cloud(f) if _cloud(f) is not None else 101.0,
            -timestamp(f),
        )
    )

    result: list[dict[str, Any]] = []
    dates: set[str] = set()
    for feature in usable:
        day = _date_key(feature)
        if day in dates:
            continue
        result.append(feature)
        dates.add(day)
        if len(result) >= 2:
            break
    return result

def _sample_asset(
    href: str,
    latitude: float,
    longitude: float,
    raster_band: list[dict[str, Any]] | None,
) -> float:
    with rasterio.open(href) as dataset:
        from rasterio.warp import transform

        xs, ys = transform(
            "EPSG:4326",
            dataset.crs,
            [longitude],
            [latitude],
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
            raise ValueError("No valid raster pixels at the requested location.")

        scale = 1.0
        offset = 0.0
        if raster_band:
            scale = raster_band[0].get("scale", 1.0) or 1.0
            offset = raster_band[0].get("offset", 0.0) or 0.0
        return float((valid * scale + offset).mean())


async def _load_item(feature: dict[str, Any]) -> dict[str, Any]:
    item_id = feature.get("id")
    if not item_id:
        raise ValueError("Satellite scene has no item ID.")

    item_url = f"https://earth-search.aws.element84.com/v1/collections/{COLLECTION}/items/{item_id}"
    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            response = await client.get(item_url)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Satellite item request failed: {exc}") from exc

    if response.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Satellite item returned HTTP {response.status_code}.")
    return response.json()


def _index(nir: float | None, red: float | None, denominator: float) -> float | None:
    if nir is None or red is None or denominator == 0:
        return None
    return max(-1.0, min(1.0, (nir - red) / denominator))


async def _analyze_scene(feature: dict[str, Any], lat: float, lon: float) -> dict[str, Any]:
    item = await _load_item(feature)
    assets = item.get("assets", {})

    required = {"red": assets.get("red"), "nir": assets.get("nir")}
    if not required["red"] or not required["nir"]:
        raise ValueError("Selected Sentinel-2 scene does not expose Red and NIR assets.")

    values: dict[str, float | None] = {}
    for name in ("blue", "red", "nir", "swir16"):
        asset = assets.get(name)
        if not asset or not asset.get("href"):
            values[name] = None
            continue
        try:
            values[name] = _sample_asset(
                asset["href"],
                lat,
                lon,
                asset.get("raster:bands"),
            )
        except Exception:
            values[name] = None

    nir = values["nir"]
    red = values["red"]
    blue = values["blue"]
    swir = values["swir16"]

    ndvi = None if nir is None or red is None or nir + red == 0 else (nir - red) / (nir + red)
    ndmi = None if nir is None or swir is None or nir + swir == 0 else (nir - swir) / (nir + swir)
    evi_denominator = None if nir is None or red is None or blue is None else nir + 6 * red - 7.5 * blue + 1
    evi = None if evi_denominator is None or evi_denominator == 0 else 2.5 * (nir - red) / evi_denominator

    def clamp(value: float | None) -> float | None:
        if value is None:
            return None
        return max(-1.0, min(1.0, value))

    return {
        "scene_id": feature.get("id"),
        "observation_date": feature.get("properties", {}).get("datetime"),
        "cloud_cover_percent": _cloud(feature),
        "indices": {
            "ndvi": clamp(ndvi),
            "ndmi": clamp(ndmi),
            "evi": clamp(evi),
        },
        "reflectance": {
            "blue": blue,
            "red": red,
            "nir": nir,
            "swir16": swir,
        },
        "coordinates": {"latitude": lat, "longitude": lon},
        "sampling": "5x5 pixel point sample around requested coordinate",
        "source": "Sentinel-2 Collection 1 L2A / AWS Open Data",
    }


@router.post("/intelligence")
async def satellite_intelligence(request: SatelliteIntelligenceRequest):
    _validate(request)
    features = await _search_features(request.latitude, request.longitude, request.days)

    selected = _choose(features, request.max_cloud_cover)
    if not selected:
        return {
            "available": False,
            "source": "Sentinel-2 Collection 1 L2A / AWS Open Data",
            "message": "No Sentinel-2 scene met the requested cloud-cover threshold.",
            "selection": {
                "days_searched": request.days,
                "max_cloud_cover_percent": request.max_cloud_cover,
                "candidate_count": len(features),
            },
        }

    scenes: list[dict[str, Any]] = []
    errors: list[str] = []
    for feature in selected:
        try:
            scenes.append(await _analyze_scene(feature, request.latitude, request.longitude))
        except Exception as exc:
            errors.append(f"{feature.get('id', 'unknown')}: {exc}")

    if not scenes:
        raise HTTPException(status_code=502, detail="Selected Sentinel-2 scenes could not be sampled.")

    latest = scenes[0]
    previous = scenes[1] if len(scenes) > 1 else None

    # Sort sampled scenes chronologically after analysis.
    scenes.sort(key=lambda scene: scene.get("observation_date") or "", reverse=True)
    latest = scenes[0]
    previous = scenes[1] if len(scenes) > 1 else None

    changes: dict[str, float | None] = {}
    if previous:
        for name in ("ndvi", "ndmi", "evi"):
            current_value = latest["indices"].get(name)
            previous_value = previous["indices"].get(name)
            changes[name] = (
                None
                if current_value is None or previous_value is None
                else round(current_value - previous_value, 6)
            )

    return {
        "available": True,
        "source": "Sentinel-2 Collection 1 L2A / AWS Open Data",
        "coordinates": {"latitude": request.latitude, "longitude": request.longitude},
        "selection": {
            "strategy": "cloud-aware: only scenes at or below the requested cloud threshold; lowest-cloud scenes preferred, newest used when cloud quality is tied",
            "days_searched": request.days,
            "max_cloud_cover_percent": request.max_cloud_cover,
            "candidate_count": len(features),
            "selected_scene_count": len(scenes),
        },
        "latest": latest,
        "previous": previous,
        "change": {
            "absolute_index_change": changes,
            "interpretation_note": "Index change is an observation between two point samples. It does not establish cause or represent a whole-farm score.",
        },
        "errors": errors,
    }
