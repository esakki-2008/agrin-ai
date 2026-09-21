from datetime import datetime, timedelta, timezone
import io

import httpx
import rasterio
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="AgriN AI Data API", version="0.2.0")

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
        raise HTTPException(
            status_code=502,
            detail=f"SoilGrids WCS returned HTTP {response.status_code}.",
        )

    content_type = response.headers.get("content-type", "").lower()

    if (
        "tiff" not in content_type
        and "image/" not in content_type
        and not response.content.startswith(b"II*\x00")
        and not response.content.startswith(b"MM\x00*")
    ):
        raise HTTPException(
            status_code=502,
            detail=(
                "SoilGrids did not return a GeoTIFF. "
                f"Content-Type: {content_type}. "
                f"Response: {response.text[:500]}"
            ),
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
        raise HTTPException(
            status_code=502,
            detail=f"Unable to read SoilGrids GeoTIFF: {exc}",
        ) from exc


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

    # Earth Search STAC is public; no AWS credentials are required.
    stac_url = "https://earth-search.aws.element84.com/v1/search"
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=request.days)

    payload = {
        "collections": ["sentinel-2-l2a"],
        "datetime": f"{start.isoformat().replace('+00:00', 'Z')}/{now.isoformat().replace('+00:00', 'Z')}",
        "intersects": {
            "type": "Point",
            "coordinates": [request.longitude, request.latitude],
        },
        "limit": 10,
        "query": {
            "eo:cloud_cover": {"lte": request.max_cloud_cover},
        },
    }

    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            response = await client.post(stac_url, json=payload)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Satellite catalog request failed: {exc}") from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Satellite catalog returned HTTP {response.status_code}.",
        )

    try:
        catalog = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Satellite catalog returned invalid JSON.") from exc

    features = catalog.get("features", [])
    results = []

    for feature in features:
        properties = feature.get("properties", {})
        results.append(
            {
                "id": feature.get("id"),
                "datetime": properties.get("datetime"),
                "cloud_cover": properties.get("eo:cloud_cover"),
                "collection": feature.get("collection"),
                "assets": sorted(feature.get("assets", {}).keys()),
            }
        )

    return {
        "source": "AWS Open Data / Earth Search STAC",
        "collection": "sentinel-2-l2a",
        "coordinates": {
            "latitude": request.latitude,
            "longitude": request.longitude,
        },
        "days_searched": request.days,
        "max_cloud_cover_percent": request.max_cloud_cover,
        "count": len(results),
        "scenes": results,
    }
