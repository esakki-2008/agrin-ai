from datetime import datetime, timedelta, timezone
import io

import httpx
import rasterio
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="AgriN AI Data API", version="0.2.1")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class SoilRequest(BaseModel):
    latitude: float
    longitude: float


class SatelliteRequest(BaseModel):
    latitude: float
    longitude: float
    days: int = 30
    max_cloud_cover: float = 30.0


def wcs_url(property_name: str, coverage: str, lon: float, lat: float):
    delta = 0.05
    url = "https://maps.isric.org/mapserv"
    params = [
        ("map", f"/map/{property_name}.map"),
        ("SERVICE", "WCS"),
        ("VERSION", "2.0.1"),
        ("REQUEST", "GetCoverage"),
        ("COVERAGEID", coverage),
        ("FORMAT", "GEOTIFF_INT16"),
        ("SUBSET", f"X({lon - delta},{lon + delta})"),
        ("SUBSET", f"Y({lat - delta},{lat + delta})"),
        ("SUBSETTINGCRS", "http://www.opengis.net/def/crs/EPSG/0/4326"),
        ("OUTPUTCRS", "http://www.opengis.net/def/crs/EPSG/0/4326"),
    ]
    return url, params


async def sample(property_name: str, coverage: str, lon: float, lat: float) -> float:
    url, params = wcs_url(property_name, coverage, lon, lat)
    async with httpx.AsyncClient(timeout=60, follow_redirects=True) as client:
        response = await client.get(url, params=params)

    if response.status_code != 200:
        raise HTTPException(status_code=502, detail=f"SoilGrids WCS returned HTTP {response.status_code}.")

    content_type = response.headers.get("content-type", "").lower()
    if (
        "tiff" not in content_type
        and "image/" not in content_type
        and not response.content.startswith(b"II*\x00")
        and not response.content.startswith(b"MM\x00*")
    ):
        raise HTTPException(
            status_code=502,
            detail=f"SoilGrids did not return a GeoTIFF. Content-Type: {content_type}. Response: {response.text[:500]}",
        )

    try:
        with rasterio.open(io.BytesIO(response.content)) as dataset:
            values = dataset.read(1, masked=True)
            data = values.compressed()
            data = data[data > 0]
            if len(data) == 0:
                raise ValueError("No valid SoilGrids pixels found for this location.")
            return float(data.mean())
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Unable to read SoilGrids GeoTIFF: {exc}") from exc


@app.get("/health")
async def health():
    return {"ok": True, "service": "AgriN Data API"}


@app.post("/soil")
async def soil(request: SoilRequest):
    if not (-90 <= request.latitude <= 90 and -180 <= request.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")

    try:
        ph_raw = await sample("phh2o", "phh2o_0-5cm_Q0.5", request.longitude, request.latitude)
        soc_raw = await sample("soc", "soc_0-5cm_Q0.5", request.longitude, request.latitude)
        nitrogen_raw = await sample("nitrogen", "nitrogen_0-5cm_Q0.5", request.longitude, request.latitude)
        clay_raw = await sample("clay", "clay_0-5cm_Q0.5", request.longitude, request.latitude)
        return {
            "source": "ISRIC SoilGrids 2.0",
            "resolution_m": 250,
            "depth": "0-5cm",
            "ph": round(ph_raw / 10, 2),
            "organic_carbon_g_kg": round(soc_raw / 10, 2),
            "nitrogen_g_kg": round(nitrogen_raw / 100, 3),
            "clay_percent": round(clay_raw / 10, 2),
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.post("/satellite/search")
async def satellite_search(request: SatelliteRequest):
    if not (-90 <= request.latitude <= 90 and -180 <= request.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")
    if not (1 <= request.days <= 90):
        raise HTTPException(status_code=400, detail="days must be between 1 and 90.")
    if not (0 <= request.max_cloud_cover <= 100):
        raise HTTPException(status_code=400, detail="max_cloud_cover must be between 0 and 100.")

    stac_url = "https://earth-search.aws.element84.com/v1/search"
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=request.days)

    # Use the current Collection 1 L2A catalog. Do not use the server-side
    # eo:cloud_cover query because Earth Search has had query-extension issues.
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
            response = await client.post(stac_url, json=payload)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Satellite catalog request failed: {exc}") from exc

    if response.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Satellite catalog returned HTTP {response.status_code}.")

    try:
        catalog = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Satellite catalog returned invalid JSON.") from exc

    results = []
    for feature in catalog.get("features", []):
        properties = feature.get("properties", {})
        cloud = properties.get("eo:cloud_cover")
        if cloud is None or float(cloud) <= request.max_cloud_cover:
            results.append({
                "id": feature.get("id"),
                "datetime": properties.get("datetime"),
                "cloud_cover": cloud,
                "collection": feature.get("collection"),
                "assets": sorted(feature.get("assets", {}).keys()),
            })

    results.sort(key=lambda item: item.get("datetime") or "", reverse=True)
    results = results[:10]

    return {
        "source": "AWS Open Data / Earth Search STAC",
        "collection": "sentinel-2-c1-l2a",
        "coordinates": {"latitude": request.latitude, "longitude": request.longitude},
        "days_searched": request.days,
        "max_cloud_cover_percent": request.max_cloud_cover,
        "count": len(results),
        "scenes": results,
    }


async def find_satellite_scene(
    latitude: float,
    longitude: float,
    days: int,
    max_cloud_cover: float,
):
    stac_url = "https://earth-search.aws.element84.com/v1/search"
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)

    payload = {
        "collections": ["sentinel-2-c1-l2a"],
        "datetime": f"{start.isoformat().replace('+00:00', 'Z')}/{now.isoformat().replace('+00:00', 'Z')}",
        "intersects": {
            "type": "Point",
            "coordinates": [longitude, latitude],
        },
        "limit": 50,
    }

    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        response = await client.post(stac_url, json=payload)

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Satellite catalog returned HTTP {response.status_code}.",
        )

    features = response.json().get("features", [])
    candidates = []

    for feature in features:
        cloud = feature.get("properties", {}).get("eo:cloud_cover")
        if cloud is not None and float(cloud) <= max_cloud_cover:
            candidates.append(feature)

    candidates.sort(
        key=lambda feature: feature.get("properties", {}).get("datetime") or "",
        reverse=True,
    )

    if not candidates:
        return None

    return candidates[0]


@app.post("/satellite/ndvi")
async def satellite_ndvi(request: SatelliteRequest):
    if not (-90 <= request.latitude <= 90 and -180 <= request.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")
    if not (1 <= request.days <= 90):
        raise HTTPException(status_code=400, detail="days must be between 1 and 90.")
    if not (0 <= request.max_cloud_cover <= 100):
        raise HTTPException(status_code=400, detail="max_cloud_cover must be between 0 and 100.")

    try:
        feature = await find_satellite_scene(
            request.latitude,
            request.longitude,
            request.days,
            request.max_cloud_cover,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Satellite catalog request failed: {exc}") from exc

    if feature is None:
        return {
            "available": False,
            "source": "AWS Open Data / Earth Search STAC",
            "message": "No suitable Sentinel-2 scene was found for the selected period and cloud threshold.",
        }

    item_id = feature.get("id")
    item_url = f"https://earth-search.aws.element84.com/v1/collections/sentinel-2-c1-l2a/items/{item_id}"

    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            item_response = await client.get(item_url)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Satellite item request failed: {exc}") from exc

    if item_response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Satellite item returned HTTP {item_response.status_code}.",
        )

    item = item_response.json()
    assets = item.get("assets", {})
    red_asset = assets.get("red")
    nir_asset = assets.get("nir")

    if not red_asset or not nir_asset:
        raise HTTPException(
            status_code=502,
            detail="Selected Sentinel-2 scene does not expose Red/NIR COG assets.",
        )

    red_href = red_asset.get("href")
    nir_href = nir_asset.get("href")
    if not red_href or not nir_href:
        raise HTTPException(status_code=502, detail="Sentinel-2 Red/NIR asset URLs are unavailable.")

    def sample_cog(href: str) -> float:
        try:
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
                    raise ValueError("No valid raster pixels at the requested location.")
                scale = 1.0
                offset = 0.0
                bands = red_asset.get("raster:bands", []) if href == red_href else nir_asset.get("raster:bands", [])
                if bands:
                    scale = bands[0].get("scale", 1.0) or 1.0
                    offset = bands[0].get("offset", 0.0) or 0.0
                return float((valid * scale + offset).mean())
        except Exception as exc:
            raise RuntimeError(f"Unable to read Sentinel-2 COG: {exc}") from exc

    try:
        red = sample_cog(red_href)
        nir = sample_cog(nir_href)
    except RuntimeError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    denominator = nir + red
    if denominator == 0:
        raise HTTPException(status_code=502, detail="Cannot calculate NDVI because Red + NIR is zero.")

    ndvi = (nir - red) / denominator
    ndvi = max(-1.0, min(1.0, ndvi))

    properties = feature.get("properties", {})

    return {
        "available": True,
        "source": "Sentinel-2 Collection 1 L2A / AWS Open Data",
        "scene_id": item_id,
        "observation_date": properties.get("datetime"),
        "cloud_cover_percent": round(float(properties.get("eo:cloud_cover")), 2)
        if properties.get("eo:cloud_cover") is not None
        else None,
        "red_reflectance": round(red, 6),
        "nir_reflectance": round(nir, 6),
        "ndvi": round(ndvi, 6),
        "coordinates": {
            "latitude": request.latitude,
            "longitude": request.longitude,
        },
    }
