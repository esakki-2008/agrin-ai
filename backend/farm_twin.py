import asyncio
from datetime import datetime, timezone
from typing import Any
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from data_sources import sample, _get_http_client
from satellite_intelligence import _search_features, _choose, _analyze_scene

router = APIRouter(prefix="/farm-twin", tags=["Farm Digital Twin"])

class FarmTwinRequest(BaseModel):
    location: str
    crop: str = "Rice"
    farm_size_acres: float | None = None

async def _geocode(location: str) -> dict[str, Any]:
    try:
        client = await _get_http_client()
        r=await client.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={"name":location,"count":1,"language":"en","format":"json"},
            timeout=20,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502,detail="Location lookup failed.") from exc
    if r.status_code!=200:
        raise HTTPException(status_code=502,detail="Location lookup returned an error.")
    results=r.json().get("results",[])
    if not results:
        raise HTTPException(status_code=404,detail="Location could not be resolved.")
    x=results[0]
    return {"name":x.get("name"),"country":x.get("country"),"latitude":x.get("latitude"),"longitude":x.get("longitude")}

@router.post("/build")
async def build_farm_twin(request: FarmTwinRequest):
    if not request.location.strip():
        raise HTTPException(status_code=400,detail="Location is required.")
    if len(request.location.strip()) > 120:
        raise HTTPException(status_code=400,detail="Location is too long.")
    if not request.crop.strip():
        raise HTTPException(status_code=400,detail="Crop is required.")
    if len(request.crop.strip()) > 80:
        raise HTTPException(status_code=400,detail="Crop name is too long.")
    if request.farm_size_acres is not None and not (0 < request.farm_size_acres <= 100000):
        raise HTTPException(status_code=400,detail="Farm size must be between 0 and 100000 acres.")

    place=await _geocode(request.location)
    lat,lon=place["latitude"],place["longitude"]

    async def fetch_weather():
        try:
            client = await _get_http_client()
            r=await client.get(
                "https://api.open-meteo.com/v1/forecast",
                params={
                    "latitude":lat,"longitude":lon,"current":"temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code","timezone":"auto"
                },
                timeout=25,
            )
            return r.json() if r.status_code==200 else {}
        except httpx.HTTPError:
            return {}

    async def fetch_soil():
        try:
            ph_raw, soc_raw, nitrogen_raw, clay_raw = await asyncio.gather(
                sample("phh2o","phh2o_0-5cm_Q0.5",lon,lat),
                sample("soc","soc_0-5cm_Q0.5",lon,lat),
                sample("nitrogen","nitrogen_0-5cm_Q0.5",lon,lat),
                sample("clay","clay_0-5cm_Q0.5",lon,lat),
            )
            return {
                "ph":round(ph_raw/10,2),
                "organic_carbon_g_kg":round(soc_raw/10,2),
                "nitrogen_g_kg":round(nitrogen_raw/100,3),
                "clay_percent":round(clay_raw/10,2),
            }
        except Exception:
            return {}

    async def fetch_satellite():
        try:
            features=await _search_features(lat,lon,180)
            selected=_choose(features,30)
            if selected:
                return await _analyze_scene(selected[0],lat,lon)
        except Exception:
            pass
        return {}

    weather, soil, satellite = await asyncio.gather(
        fetch_weather(),
        fetch_soil(),
        fetch_satellite(),
    )

    return {
        "available":True,
        "twin_version":"1.0",
        "generated_at":datetime.now(timezone.utc).isoformat(),
        "farm":{
            "location":place,
            "crop":request.crop,
            "farm_size_acres":request.farm_size_acres,
        },
        "state":{
            "weather":weather.get("current",{}) if weather else {},
            "soil_surface":soil,
            "satellite":satellite,
        },
        "state_semantics":{
            "weather":"Live forecast-provider current conditions at the resolved coordinate.",
            "soil":"Model-derived SoilGrids surface estimate, approximately 250 m resolution.",
            "satellite":"Cloud-aware Sentinel-2 point observation when a suitable scene is available.",
        },
        "actions":["Refresh the twin to obtain a new observation snapshot.","Compare repeated snapshots rather than treating one observation as a trend.","Verify field conditions before operational decisions."],
        "limitations":[
            "This is an observation snapshot, not a cadastral farm boundary or complete physical simulation.",
            "No farm polygon was supplied, so satellite values represent a point sample.",
            "No measured soil moisture, irrigation-system telemetry, crop-stage record, yield record, or field sensor data is included.",
            "A location name resolves to a representative coordinate and may not be the exact farm boundary.",
        ],
    }
