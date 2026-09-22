from datetime import datetime, timezone
from typing import Any
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/water", tags=["Water & Irrigation Intelligence"])

class WaterRequest(BaseModel):
    latitude: float
    longitude: float
    forecast_days: int = 7

def _validate(r: WaterRequest):
    if not (-90 <= r.latitude <= 90 and -180 <= r.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")
    if not 1 <= r.forecast_days <= 16:
        raise HTTPException(status_code=400, detail="forecast_days must be between 1 and 16.")

@router.post("/intelligence")
async def water_intelligence(r: WaterRequest):
    _validate(r)
    params = {
        "latitude": r.latitude, "longitude": r.longitude,
        "forecast_days": r.forecast_days, "timezone": "auto",
        "daily": "precipitation_sum,precipitation_probability_max,et0_fao_evapotranspiration,temperature_2m_mean",
    }
    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            response = await client.get("https://api.open-meteo.com/v1/forecast", params=params)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Water forecast request failed: {exc}") from exc
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Water forecast returned HTTP {response.status_code}.")
    try:
        body = response.json()
        daily = body["daily"]
    except (ValueError, KeyError, TypeError) as exc:
        raise HTTPException(status_code=502, detail="Water forecast returned an invalid response.") from exc

    rows: list[dict[str, Any]] = []
    for i, date in enumerate(daily.get("time", [])):
        rows.append({
            "date": date,
            "precipitation_mm": daily["precipitation_sum"][i],
            "precipitation_probability_percent": daily["precipitation_probability_max"][i],
            "et0_mm": daily["et0_fao_evapotranspiration"][i],
            "temperature_mean_c": daily["temperature_2m_mean"][i],
        })

    def total(key):
        vals=[float(x[key]) for x in rows if x[key] is not None]
        return round(sum(vals),2) if vals else None
    rain=total("precipitation_mm")
    et0=total("et0_mm")
    probs=[float(x["precipitation_probability_percent"]) for x in rows if x["precipitation_probability_percent"] is not None]
    max_prob=round(max(probs),2) if probs else None
    atmospheric_balance=round(rain-et0,2) if rain is not None and et0 is not None else None

    signals=[]
    if rain is not None and et0 is not None and atmospheric_balance < 0:
        signals.append({
            "type":"forecast_water_balance",
            "status":"precipitation_below_reference_et0",
            "evidence":f"Forecast precipitation is {rain:.1f} mm versus reference ET0 of {et0:.1f} mm; difference {atmospheric_balance:.1f} mm.",
            "meaning":"Atmospheric water input is below reference evaporative demand over the forecast window.",
        })
    if max_prob is not None and max_prob >= 70:
        signals.append({
            "type":"rain_event_probability",
            "status":"elevated",
            "evidence":f"Maximum forecast precipitation probability is {max_prob:.0f}%.",
            "meaning":"Use the forecast to time field checks; probability is not measured rainfall.",
        })
    if rain == 0:
        signals.append({
            "type":"forecast_rainfall",
            "status":"zero_forecast_precipitation",
            "evidence":"Forecast precipitation totals are 0 mm for the requested window.",
        })

    return {
        "available": True,
        "source":"Open-Meteo Forecast API",
        "generated_at":datetime.now(timezone.utc).isoformat(),
        "coordinates":{"latitude":r.latitude,"longitude":r.longitude},
        "timezone":body.get("timezone"),
        "forecast_days":len(rows),
        "summary":{
            "forecast_precipitation_mm":rain,
            "reference_et0_mm":et0,
            "precipitation_minus_reference_et0_mm":atmospheric_balance,
            "maximum_precipitation_probability_percent":max_prob,
        },
        "signals":signals,
        "daily":rows,
        "decision_support":[
            "Do not convert this atmospheric balance into an irrigation volume without measured field soil moisture, crop water requirements, effective rainfall, and irrigation-system information.",
            "Check actual soil moisture in the field before deciding whether irrigation is required.",
            "After rainfall, verify infiltration and field conditions rather than assuming all forecast precipitation became root-zone water.",
        ],
        "limitations":[
            "Reference ET0 is atmospheric demand for a reference surface, not crop evapotranspiration.",
            "Forecast precipitation is not the same as effective root-zone rainfall.",
            "No soil-moisture sensor or farm irrigation-system measurement is used by this endpoint.",
        ],
    }
