from typing import Any
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from data_sources import sample

router = APIRouter(prefix="/soil-intelligence", tags=["Soil Intelligence"])

DEPTHS = {
    "0-5cm": "0-5cm",
    "5-15cm": "5-15cm",
    "15-30cm": "15-30cm",
    "30-60cm": "30-60cm",
    "60-100cm": "60-100cm",
    "100-200cm": "100-200cm",
}

class SoilIntelligenceRequest(BaseModel):
    latitude: float
    longitude: float

async def _depth_values(lat: float, lon: float, depth: str) -> dict[str, float]:
    return {
        "ph": round((await sample("phh2o", f"phh2o_{depth}_Q0.5", lon, lat)) / 10, 2),
        "organic_carbon_g_kg": round((await sample("soc", f"soc_{depth}_Q0.5", lon, lat)) / 10, 2),
        "nitrogen_g_kg": round((await sample("nitrogen", f"nitrogen_{depth}_Q0.5", lon, lat)) / 100, 3),
        "clay_percent": round((await sample("clay", f"clay_{depth}_Q0.5", lon, lat)) / 10, 2),
    }

@router.post("/profile")
async def soil_profile(request: SoilIntelligenceRequest):
    if not (-90 <= request.latitude <= 90 and -180 <= request.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")

    profile: list[dict[str, Any]] = []
    errors: list[str] = []

    for label, depth in DEPTHS.items():
        try:
            values = await _depth_values(request.latitude, request.longitude, depth)
            profile.append({"depth": label, **values})
        except HTTPException as exc:
            errors.append(f"{label}: {exc.detail}")
        except Exception as exc:
            errors.append(f"{label}: {exc}")

    if not profile:
        raise HTTPException(status_code=502, detail="No SoilGrids depth profile could be retrieved.")

    return {
        "available": True,
        "source": "ISRIC SoilGrids 2.0",
        "resolution_m": 250,
        "coordinates": {"latitude": request.latitude, "longitude": request.longitude},
        "profile": profile,
        "errors": errors,
        "interpretation": {
            "organic_carbon": "Model-derived soil organic carbon concentration; not a laboratory measurement.",
            "nitrogen": "Model-derived total nitrogen concentration; not a fertilizer recommendation or deficiency diagnosis.",
            "ph": "Model-derived pH; interpretation depends on crop and local agronomic reference ranges.",
            "clay": "Model-derived clay content; useful as a soil-texture signal, not a field texture test.",
        },
        "limitations": [
            "SoilGrids values are spatial model estimates at approximately 250 m resolution.",
            "They are not a substitute for a farm soil laboratory test.",
            "Raw concentrations are reported without declaring nutrient sufficiency or deficiency.",
        ],
    }

@router.post("/texture")
async def soil_texture(request: SoilIntelligenceRequest):
    result = await soil_profile(request)
    rows = result["profile"]
    return {
        "available": True,
        "source": result["source"],
        "resolution_m": result["resolution_m"],
        "coordinates": result["coordinates"],
        "layers": [
            {
                "depth": row["depth"],
                "clay_percent": row["clay_percent"],
                "texture_signal": (
                    "Higher clay content than the other sampled layers"
                    if row["clay_percent"] > max(r["clay_percent"] for r in rows)
                    else "Not classified against a formal texture triangle"
                ),
            }
            for row in rows
        ],
        "limitation": "This is a relative profile signal, not a formal USDA/FAO texture classification.",
    }
