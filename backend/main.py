from datetime import datetime, timedelta, timezone
from pathlib import Path
import base64
import json

import httpx
import rasterio
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from data_sources import sample, find_satellite_scene

from regenerative import router as regenerative_router
from historical import router as historical_router
from interoperability import router as interoperability_router
from agent import router as agent_router
from satellite_intelligence import router as satellite_intelligence_router
from climate import router as climate_router
from soil_intelligence import router as soil_intelligence_router
from water_intelligence import router as water_intelligence_router
from farm_twin import router as farm_twin_router
from agri_network import router as agri_network_router

load_dotenv(dotenv_path=Path(__file__).resolve().parent / '.env')

app = FastAPI(
    title="AgriN AI Data API",
    version="0.2.1",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(regenerative_router)
app.include_router(historical_router)
app.include_router(interoperability_router)
app.include_router(agent_router)
app.include_router(satellite_intelligence_router)
app.include_router(climate_router)
app.include_router(soil_intelligence_router)
app.include_router(water_intelligence_router)
app.include_router(farm_twin_router)
app.include_router(agri_network_router)


# ============================================================
# HEALTH
# ============================================================

@app.get("/health")
async def health():
    return {
        "ok": True,
        "service": "AgriN Data API",
    }


# ============================================================
# SOIL
# ============================================================

class SoilRequest(BaseModel):
    latitude: float
    longitude: float


@app.post("/soil")
async def soil(request: SoilRequest):
    if not (
        -90 <= request.latitude <= 90
        and -180 <= request.longitude <= 180
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid coordinates.",
        )

    try:
        ph_raw = await sample(
            "phh2o",
            "phh2o_0-5cm_Q0.5",
            request.longitude,
            request.latitude,
        )

        soc_raw = await sample(
            "soc",
            "soc_0-5cm_Q0.5",
            request.longitude,
            request.latitude,
        )

        nitrogen_raw = await sample(
            "nitrogen",
            "nitrogen_0-5cm_Q0.5",
            request.longitude,
            request.latitude,
        )

        clay_raw = await sample(
            "clay",
            "clay_0-5cm_Q0.5",
            request.longitude,
            request.latitude,
        )

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
        raise HTTPException(
            status_code=502,
            detail=str(exc),
        ) from exc


# ============================================================
# SATELLITE SEARCH
# ============================================================

class SatelliteRequest(BaseModel):
    latitude: float
    longitude: float
    days: int = 30
    max_cloud_cover: float = 30.0


@app.post("/satellite/search")
async def satellite_search(request: SatelliteRequest):
    if not (
        -90 <= request.latitude <= 90
        and -180 <= request.longitude <= 180
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid coordinates.",
        )

    if not (1 <= request.days <= 90):
        raise HTTPException(
            status_code=400,
            detail="days must be between 1 and 90.",
        )

    if not (0 <= request.max_cloud_cover <= 100):
        raise HTTPException(
            status_code=400,
            detail="max_cloud_cover must be between 0 and 100.",
        )

    stac_url = (
        "https://earth-search.aws.element84.com/v1/search"
    )

    now = datetime.now(timezone.utc)
    start = now - timedelta(days=request.days)

    payload = {
        "collections": [
            "sentinel-2-c1-l2a"
        ],
        "datetime": (
            f"{start.isoformat().replace('+00:00', 'Z')}/"
            f"{now.isoformat().replace('+00:00', 'Z')}"
        ),
        "intersects": {
            "type": "Point",
            "coordinates": [
                request.longitude,
                request.latitude,
            ],
        },
        "limit": 50,
    }

    try:
        async with httpx.AsyncClient(
            timeout=30,
            follow_redirects=True,
        ) as client:
            response = await client.post(
                stac_url,
                json=payload,
            )

    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                f"Satellite catalog request failed: {exc}"
            ),
        ) from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=(
                "Satellite catalog returned HTTP "
                f"{response.status_code}."
            ),
        )

    try:
        catalog = response.json()

    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail="Satellite catalog returned invalid JSON.",
        ) from exc

    results = []

    for feature in catalog.get("features", []):
        properties = feature.get(
            "properties",
            {},
        )

        cloud = properties.get(
            "eo:cloud_cover"
        )

        if cloud is None or float(cloud) <= request.max_cloud_cover:
            results.append(
                {
                    "id": feature.get("id"),
                    "datetime": properties.get("datetime"),
                    "cloud_cover": cloud,
                    "collection": feature.get("collection"),
                    "assets": sorted(
                        feature.get(
                            "assets",
                            {},
                        ).keys()
                    ),
                }
            )

    results.sort(
        key=lambda item: item.get("datetime") or "",
        reverse=True,
    )

    results = results[:10]

    return {
        "source": "AWS Open Data / Earth Search STAC",
        "collection": "sentinel-2-c1-l2a",
        "coordinates": {
            "latitude": request.latitude,
            "longitude": request.longitude,
        },
        "days_searched": request.days,
        "max_cloud_cover_percent": request.max_cloud_cover,
        "count": len(results),
        "scenes": results,
    }


# ============================================================
# SATELLITE NDVI
# ============================================================

@app.post("/satellite/ndvi")
async def satellite_ndvi(request: SatelliteRequest):
    if not (
        -90 <= request.latitude <= 90
        and -180 <= request.longitude <= 180
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid coordinates.",
        )

    if not (1 <= request.days <= 90):
        raise HTTPException(
            status_code=400,
            detail="days must be between 1 and 90.",
        )

    if not (0 <= request.max_cloud_cover <= 100):
        raise HTTPException(
            status_code=400,
            detail="max_cloud_cover must be between 0 and 100.",
        )

    try:
        feature = await find_satellite_scene(
            request.latitude,
            request.longitude,
            request.days,
            request.max_cloud_cover,
        )

    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                f"Satellite catalog request failed: {exc}"
            ),
        ) from exc

    if feature is None:
        return {
            "available": False,
            "source": (
                "AWS Open Data / Earth Search STAC"
            ),
            "message": (
                "No suitable Sentinel-2 scene was found "
                "for the selected period and cloud threshold."
            ),
        }

    item_id = feature.get("id")

    if not item_id:
        raise HTTPException(
            status_code=502,
            detail="Satellite catalog returned a scene without an ID.",
        )

    item_url = (
        "https://earth-search.aws.element84.com/v1/"
        f"collections/sentinel-2-c1-l2a/items/{item_id}"
    )

    try:
        async with httpx.AsyncClient(
            timeout=30,
            follow_redirects=True,
        ) as client:
            item_response = await client.get(
                item_url
            )

    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                f"Satellite item request failed: {exc}"
            ),
        ) from exc

    if item_response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=(
                "Satellite item returned HTTP "
                f"{item_response.status_code}."
            ),
        )

    try:
        item = item_response.json()

    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail="Satellite item returned invalid JSON.",
        ) from exc

    assets = item.get("assets", {})

    red_asset = assets.get("red")
    nir_asset = assets.get("nir")

    if not red_asset or not nir_asset:
        raise HTTPException(
            status_code=502,
            detail=(
                "Selected Sentinel-2 scene does not expose "
                "Red/NIR COG assets."
            ),
        )

    red_href = red_asset.get("href")
    nir_href = nir_asset.get("href")

    if not red_href or not nir_href:
        raise HTTPException(
            status_code=502,
            detail=(
                "Sentinel-2 Red/NIR asset URLs are unavailable."
            ),
        )

    def sample_cog(
        href: str,
        asset: dict,
    ) -> float:
        try:
            with rasterio.open(href) as dataset:
                from rasterio.warp import transform

                xs, ys = transform(
                    "EPSG:4326",
                    dataset.crs,
                    [request.longitude],
                    [request.latitude],
                )

                row, col = dataset.index(
                    xs[0],
                    ys[0],
                )

                half = 2

                window = rasterio.windows.Window(
                    max(0, col - half),
                    max(0, row - half),
                    5,
                    5,
                )

                values = dataset.read(
                    1,
                    window=window,
                    masked=True,
                ).astype("float64")

                valid = values.compressed()
                valid = valid[valid >= 0]

                if len(valid) == 0:
                    raise ValueError(
                        "No valid raster pixels at the requested location."
                    )

                scale = 1.0
                offset = 0.0

                bands = asset.get(
                    "raster:bands",
                    [],
                )

                if bands:
                    scale = (
                        bands[0].get(
                            "scale",
                            1.0,
                        )
                        or 1.0
                    )

                    offset = (
                        bands[0].get(
                            "offset",
                            0.0,
                        )
                        or 0.0
                    )

                return float(
                    (
                        valid * scale
                        + offset
                    ).mean()
                )

        except Exception as exc:
            raise RuntimeError(
                f"Unable to read Sentinel-2 COG: {exc}"
            ) from exc

    try:
        red = sample_cog(
            red_href,
            red_asset,
        )

        nir = sample_cog(
            nir_href,
            nir_asset,
        )

    except RuntimeError as exc:
        raise HTTPException(
            status_code=502,
            detail=str(exc),
        ) from exc

    denominator = nir + red

    if denominator == 0:
        raise HTTPException(
            status_code=502,
            detail=(
                "Cannot calculate NDVI because "
                "Red + NIR is zero."
            ),
        )

    ndvi = (
        (nir - red)
        / denominator
    )

    ndvi = max(
        -1.0,
        min(1.0, ndvi),
    )

    properties = feature.get(
        "properties",
        {},
    )

    cloud_cover = properties.get(
        "eo:cloud_cover"
    )

    return {
        "available": True,
        "source": (
            "Sentinel-2 Collection 1 L2A / AWS Open Data"
        ),
        "scene_id": item_id,
        "observation_date": properties.get(
            "datetime"
        ),
        "cloud_cover_percent": (
            round(float(cloud_cover), 2)
            if cloud_cover is not None
            else None
        ),
        "red_reflectance": round(
            red,
            6,
        ),
        "nir_reflectance": round(
            nir,
            6,
        ),
        "ndvi": round(
            ndvi,
            6,
        ),
        "coordinates": {
            "latitude": request.latitude,
            "longitude": request.longitude,
        },
    }


# ============================================================
# CROP DOCTOR
# ============================================================

class DiseaseRequest(BaseModel):
    image_base64: str
    mime_type: str = "image/jpeg"
    crop: str = ""
    location: str = ""


@app.post("/disease/analyze")
async def disease_analyze(
    request: DiseaseRequest,
):
    allowed_types = {
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/heic",
        "image/heif",
    }

    if request.mime_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=(
                "Unsupported image type. "
                "Use JPEG, PNG, WebP, HEIC, or HEIF."
            ),
        )

    try:
        image_bytes = base64.b64decode(
            request.image_base64,
            validate=True,
        )

    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail="Invalid base64 image data.",
        ) from exc

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="The uploaded image is empty.",
        )

    if len(image_bytes) > 12 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=(
                "Image is too large. "
                "Please upload an image under 12 MB."
            ),
        )

    prompt = """
You are AgriN AI Crop Doctor, an agricultural image-assessment assistant.

Analyze ONLY what is visibly supported by the supplied crop/leaf image and the optional crop/location context.

Do not invent symptoms, disease names, pests, nutrient deficiencies, crop stage, severity,
treatment results, or environmental conditions.

This is visual decision support, not a definitive diagnosis.

If the image is blurry, poorly framed, shows a non-diagnostic area, or the evidence is insufficient,
say so clearly and recommend a clearer photo or field/laboratory confirmation.

Do not claim that a disease is confirmed.

Use wording such as "possible", "consistent with", or "cannot determine" when appropriate.

Do not provide chemical pesticide dosage or fertilizer dosage.

Do not recommend a specific chemical treatment unless the visual evidence is strong;
prefer practical non-chemical checks and professional/local agronomy confirmation.

Return ONLY valid JSON with exactly these fields:

{
  "assessment": "short evidence-aware assessment",
  "image_quality": {
    "status": "usable|limited|insufficient",
    "reason": "brief visual-quality reason"
  },
  "evidence_strength": "strong|moderate|weak|insufficient",
  "possible_issues": [
    "possible issue or 'No specific issue can be determined from this image.'"
  ],
  "observations": [
    "visible observation"
  ],
  "actions": [
    {
      "title": "next check",
      "reason": "why it is relevant",
      "priority": "high|medium|low"
    }
  ],
  "follow_up_questions": [
    "question that would materially improve assessment"
  ],
  "limitations": [
    "important limitation"
  ]
}

Keep it concise and farmer-friendly.

Optional context:
""" + json.dumps(
        {
            "crop": request.crop,
            "location": request.location,
        },
        ensure_ascii=False,
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
            image_base64=base64.b64encode(
                image_bytes
            ).decode("ascii"),
            mime_type=request.mime_type,
        )

    except AIProviderError as exc:
        raise HTTPException(
            status_code=503,
            detail=str(exc),
        ) from exc

    return {
        "source": "Google Gemini API",
        "model": provider_meta["model"],
        "provider": provider_meta,
        "analysis": {
            **result,
            "source": "Google Gemini API",
            "model": provider_meta["model"],
        },
    }


# ============================================================
# AI AGRO-ADVISORY
# ============================================================

class AdvisoryRequest(BaseModel):
    location: str
    crop: str
    farm_size_acres: float
    sowing_date: str

    temperature_c: float
    humidity_percent: float
    wind_kmh: float
    rain_probability_percent: float
    weather_condition: str

    soil_ph: float | None = None
    organic_carbon_g_kg: float | None = None
    nitrogen_g_kg: float | None = None
    clay_percent: float | None = None
    soil_source: str | None = None

    ndvi: float | None = None
    satellite_date: str | None = None
    satellite_cloud_cover_percent: float | None = None
    satellite_source: str | None = None


@app.post("/advisory")
async def advisory(
    request: AdvisoryRequest,
):
    measured = {
        "location": request.location,
        "crop": request.crop,
        "farm_size_acres": request.farm_size_acres,
        "sowing_date": request.sowing_date,
        "weather": {
            "temperature_c": request.temperature_c,
            "humidity_percent": request.humidity_percent,
            "wind_kmh": request.wind_kmh,
            "rain_probability_percent": (
                request.rain_probability_percent
            ),
            "condition": request.weather_condition,
        },
        "soil": {
            "ph": request.soil_ph,
            "organic_carbon_g_kg": (
                request.organic_carbon_g_kg
            ),
            "nitrogen_g_kg": request.nitrogen_g_kg,
            "clay_percent": request.clay_percent,
            "source": request.soil_source,
        },
        "satellite": {
            "ndvi": request.ndvi,
            "observation_date": request.satellite_date,
            "cloud_cover_percent": (
                request.satellite_cloud_cover_percent
            ),
            "source": request.satellite_source,
        },
    }

    prompt = """
You are AgriN AI's agricultural decision-support assistant.

Use ONLY the measured values supplied in the JSON below.

Never invent:
- missing measurements
- weather forecasts
- soil values
- crop stage
- disease presence
- irrigation amounts
- fertilizer rates
- pesticide doses
- prices
- yield predictions

Create a practical advisory for the farmer.

Distinguish measured facts from recommendations.

If a value is null, explicitly say that it is unavailable
and do not infer it.

NDVI is a satellite-derived sample observation, not automatically
a whole-farm health score.

SoilGrids is model-derived soil information, not a laboratory soil test.

Do not diagnose a disease from these measurements.

Do not classify a soil nutrient as low, high, deficient, sufficient,
optimal, or excessive unless an explicit validated reference range
is supplied in the input.

A raw SoilGrids concentration by itself is not enough to make
that classification.

Do not infer crop growth stage from the sowing date alone unless
a validated crop-calendar rule is supplied.

Use cautious language when evidence is insufficient.

Describe the measured value, explain what it can and cannot establish,
and recommend an appropriate field or laboratory check where needed.

Return ONLY valid JSON with exactly these fields:

{
  "summary": "short factual summary",
  "observations": [
    "measured observation"
  ],
  "actions": [
    {
      "title": "action title",
      "reason": "why this action is relevant to the measured data",
      "priority": "high|medium|low",
      "confidence": "high|medium|low"
    }
  ],
  "watch_items": [
    "what the farmer should monitor next"
  ],
  "data_limits": [
    "important limitation"
  ]
}

Keep the answer concise and farmer-friendly.

Do not give chemical pesticide or fertilizer dosage.

For irrigation, recommend checking field soil moisture before
deciding an irrigation amount unless a measured soil-moisture
value is actually provided.

Measured farm data:
""" + json.dumps(
        measured,
        ensure_ascii=False,
    )

    from ai_gateway import (
        AIProviderError,
        generate_json,
    )

    try:
        result, provider_meta = await generate_json(
            prompt,
            temperature=0.2,
            timeout=45,
        )

    except AIProviderError as exc:
        raise HTTPException(
            status_code=503,
            detail=str(exc),
        ) from exc

    return {
        "source": "Google Gemini API",
        "model": provider_meta["model"],
        "provider": provider_meta,
        "advisory": result,
    }