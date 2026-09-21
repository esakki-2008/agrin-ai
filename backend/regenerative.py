from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/regenerative", tags=["regenerative"])

class RegenerativeRequest(BaseModel):
    location: str
    crop: str
    temperature_c: float | None = None
    humidity_percent: float | None = None
    rain_probability_percent: float | None = None
    soil_ph: float | None = None
    organic_carbon_g_kg: float | None = None
    nitrogen_g_kg: float | None = None
    clay_percent: float | None = None
    soil_source: str | None = None

@router.post("/plan")
async def regenerative_plan(request: RegenerativeRequest):
    practices = [
        {"title":"Keep soil covered","reason":"Use crop residues, mulch, or an appropriate cover crop to reduce exposed soil between crop periods.","priority":"high","basis":"General regenerative practice"},
        {"title":"Retain useful crop residues","reason":"Where agronomically and operationally appropriate, retain or return crop residues rather than routinely removing or burning them.","priority":"high","basis":"General regenerative practice"},
        {"title":"Diversify the rotation","reason":"Plan crop rotation or compatible intercropping where suitable for the local farming system to increase crop diversity over time.","priority":"medium","basis":"General regenerative practice"},
        {"title":"Minimize unnecessary soil disturbance","reason":"Use the least soil disturbance that is practical for the crop and local field conditions.","priority":"medium","basis":"General regenerative practice"},
        {"title":"Check soil moisture before irrigation","reason":"The current dataset does not contain measured soil moisture, so irrigation decisions should be checked against field moisture rather than inferred from soil texture or rainfall probability alone.","priority":"high","basis":"Data limitation"},
    ]
    evidence = []
    if request.rain_probability_percent is not None:
        rain = request.rain_probability_percent
        evidence.append({"signal":"Rain probability","value":"%.0f%%" % rain,"interpretation":"Current weather signal only; use it to plan field operations and drainage checks, not as a soil-moisture measurement.","source":"Open-Meteo"})
        if rain >= 60:
            practices.insert(0, {"title":"Prepare drainage and avoid unnecessary field traffic before rain","reason":"Open-Meteo reports a %.0f%% current rain probability. Keep drainage paths clear and avoid avoidable traffic on wet soil." % rain,"priority":"high","basis":"Current weather signal"})
    source = request.soil_source or "SoilGrids"
    if request.organic_carbon_g_kg is not None:
        evidence.append({"signal":"Soil organic carbon","value":"%.1f g/kg" % request.organic_carbon_g_kg,"interpretation":"Model-derived SoilGrids value. Track future field or laboratory measurements to evaluate change over time.","source":source})
    if request.soil_ph is not None:
        evidence.append({"signal":"Soil pH","value":"%.2f" % request.soil_ph,"interpretation":"Model-derived value shown for context; no deficiency or amendment recommendation is inferred without a crop-specific validated reference.","source":source})
    if request.clay_percent is not None:
        evidence.append({"signal":"Clay content","value":"%.1f%%" % request.clay_percent,"interpretation":"Model-derived soil texture signal. Field moisture should still be checked directly before irrigation or machinery decisions.","source":source})
    return {
        "source":"AgriN regenerative rules engine",
        "location":request.location,
        "crop":request.crop,
        "principles":["Keep soil covered","Protect and build soil organic matter","Reduce unnecessary disturbance","Increase crop diversity","Use water and field operations based on measured conditions where possible"],
        "practices":practices,
        "evidence":evidence,
        "limitations":[
            "This plan does not diagnose crop disease or determine nutrient deficiency.",
            "SoilGrids values are model-derived at approximately 250 m resolution, not laboratory measurements.",
            "No measured soil moisture value was supplied.",
            "Crop stage, local soil-test history, irrigation system, residue availability, and farm machinery constraints were not supplied.",
            "Validate practice timing and crop-specific implementation with a local agronomist or extension service."
        ]
    }
