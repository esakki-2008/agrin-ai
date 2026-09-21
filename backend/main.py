from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import io
import httpx
import rasterio

app = FastAPI(title="AgriN AI Data API", version="0.1.1")

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


def wcs_url(property_name: str, coverage: str, lon: float, lat: float):
    # Request a wider area so the result contains multiple 250 m SoilGrids cells.
    delta = 0.05

    url = f"https://maps.isric.org/mapserv?map=/map/{property_name}.map"

    params = [
        ("SERVICE", "WCS"),
        ("VERSION", "2.0.1"),
        ("REQUEST", "GetCoverage"),
        ("COVERAGEID", coverage),
        ("FORMAT", "GEOTIFF_INT16"),
        ("SUBSET", f"X({lon - delta},{lon + delta})"),
        ("SUBSET", f"Y({lat - delta},{lat + delta})"),
        (
            "SUBSETTINGCRS",
            "http://www.opengis.net/def/crs/EPSG/0/4326",
        ),
        (
            "OUTPUTCRS",
            "http://www.opengis.net/def/crs/EPSG/0/4326",
        ),
    ]

    return url, params


async def sample(property_name: str, coverage: str, lon: float, lat: float) -> float:
    url, params = wcs_url(property_name, coverage, lon, lat)

    async with httpx.AsyncClient(
        timeout=60,
        follow_redirects=True,
    ) as client:
        response = await client.get(url, params=params)

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"SoilGrids WCS returned HTTP {response.status_code}.",
        )

    content_type = response.headers.get("content-type", "").lower()

    # Fail clearly if SoilGrids returns an XML/HTML error instead of a raster.
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

            # SoilGrids can return 0 as a background value without
            # declaring it as GeoTIFF NoData.
            data = data[data > 0]

            if len(data) == 0:
                raise ValueError(
                    "No valid SoilGrids pixels found for this location."
                )

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
    if not (
        -90 <= request.latitude <= 90
        and -180 <= request.longitude <= 180
    ):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")

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
        raise HTTPException(status_code=502, detail=str(exc)) from exc
