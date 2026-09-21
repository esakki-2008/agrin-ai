from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import io
import httpx
import rasterio

app = FastAPI(title="AgriN AI Data API", version="0.1.0")

class SoilRequest(BaseModel):
    latitude: float
    longitude: float

def wcs_url(property_name: str, coverage: str, lon: float, lat: float) -> str:
    delta = 0.0025
    params = {
        "SERVICE": "WCS",
        "VERSION": "2.0.1",
        "REQUEST": "GetCoverage",
        "COVERAGEID": coverage,
        "FORMAT": "GEOTIFF_INT16",
        "SUBSET": [f"X({lon-delta},{lon+delta})", f"Y({lat-delta},{lat+delta})"],
        "SUBSETTINGCRS": "http://www.opengis.net/def/crs/EPSG/0/4326",
        "OUTPUTCRS": "http://www.opengis.net/def/crs/EPSG/0/4326",
    }
    return "https://maps.isric.org/mapserv?map=/map/" + property_name + ".map", params

async def sample(property_name: str, coverage: str, lon: float, lat: float) -> float:
    url, params = wcs_url(property_name, coverage, lon, lat)
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(url, params=params)
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail=f"SoilGrids WCS returned {response.status_code}.")
    try:
        with rasterio.open(io.BytesIO(response.content)) as dataset:
            values = dataset.read(1, masked=True)
            if values.mask.all():
                raise ValueError("No soil pixel covers this location.")
            return float(values.compressed().mean())
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Unable to read SoilGrids coverage: {exc}") from exc

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
