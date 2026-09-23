from datetime import datetime, timezone
from typing import Any
from collections import defaultdict
import logging

import httpx
from data_sources import _get_http_client
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/water", tags=["Water & Irrigation Intelligence"])
logger = logging.getLogger(__name__)


class WaterRequest(BaseModel):
    latitude: float
    longitude: float
    forecast_days: int = 7


def _validate(r: WaterRequest):
    if not (-90 <= r.latitude <= 90 and -180 <= r.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")
    if not 1 <= r.forecast_days <= 16:
        raise HTTPException(status_code=400, detail="forecast_days must be between 1 and 16.")


async def _fetch_met_norway_forecast(
    client: httpx.AsyncClient,
    latitude: float,
    longitude: float,
    forecast_days: int,
) -> dict[str, Any]:
    url = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
    headers = {
        "User-Agent": "AgriN-AI/1.0 (https://github.com/esakki-2008/agrin-ai)",
    }

    try:
        response = await client.get(
            url,
            params={"lat": round(latitude, 4), "lon": round(longitude, 4)},
            headers=headers,
            timeout=30,
        )
    except httpx.HTTPError as exc:
        logger.warning("MET Norway water forecast transport failure: %s", type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="Water forecast request failed.",
        ) from exc

    if response.status_code != 200:
        logger.warning(
            "MET Norway water forecast failed: status=%s body=%s",
            response.status_code,
            response.text[:500].replace("\n", " "),
        )
        raise HTTPException(
            status_code=502,
            detail="Water forecast service returned an error.",
        )

    try:
        payload = response.json()
        timeseries = payload["properties"]["timeseries"]
    except (ValueError, KeyError, TypeError) as exc:
        raise HTTPException(
            status_code=502,
            detail="Water forecast returned an invalid response.",
        ) from exc

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)

    for item in timeseries:
        timestamp = item.get("time")
        if not timestamp:
            continue
        try:
            day = datetime.fromisoformat(timestamp.replace("Z", "+00:00")).date().isoformat()
        except ValueError:
            continue
        grouped[day].append(item)

    rows: list[dict[str, Any]] = []

    for day in sorted(grouped)[:forecast_days]:
        items = grouped[day]
        temperatures: list[float] = []
        precipitation: list[float] = []
        rain_prob: list[float] = []
        symbols: list[str] = []

        for item in items:
            data = item.get("data", {})
            details = data.get("instant", {}).get("details", {})

            if details.get("air_temperature") is not None:
                temperatures.append(float(details["air_temperature"]))

            # Prefer next_1_hours to avoid double-counting the overlapping
            # next_6_hours precipitation period.
            one_hour = data.get("next_1_hours", {})
            six_hours = data.get("next_6_hours", {})
            period = one_hour if one_hour else six_hours
            period_details = period.get("details", {})

            if period_details.get("precipitation_amount") is not None:
                precipitation.append(float(period_details["precipitation_amount"]))

            if period_details.get("probability_of_precipitation") is not None:
                rain_prob.append(float(period_details["probability_of_precipitation"]))

            symbol = period.get("summary", {}).get("symbol_code")
            if symbol:
                symbols.append(symbol)

        rows.append({
            "date": day,
            "precipitation_mm": round(sum(precipitation), 2),
            "precipitation_probability_percent": round(max(rain_prob), 2) if rain_prob else None,
            "et0_mm": None,
            "temperature_mean_c": round(sum(temperatures) / len(temperatures), 2) if temperatures else None,
            "weather_code": symbols[0] if symbols else None,
        })

    if not rows:
        raise HTTPException(
            status_code=502,
            detail="Water forecast returned no usable data.",
        )

    return {
        "source": "MET Norway Locationforecast",
        "timezone": "UTC",
        "daily": rows,
    }


@router.post("/intelligence")
async def water_intelligence(r: WaterRequest):
    _validate(r)

    params = {
        "latitude": r.latitude,
        "longitude": r.longitude,
        "forecast_days": r.forecast_days,
        "timezone": "auto",
        "daily": "precipitation_sum,precipitation_probability_max,et0_fao_evapotranspiration,temperature_2m_mean",
    }

    try:
        client = await _get_http_client()
        response = await client.get(
            "https://api.open-meteo.com/v1/forecast",
            params=params,
            timeout=30,
        )

        if response.status_code == 429:
            logger.warning("Open-Meteo water quota exhausted; using MET Norway fallback.")
            fallback = await _fetch_met_norway_forecast(
                client,
                r.latitude,
                r.longitude,
                r.forecast_days,
            )
            daily = fallback["daily"]
            source = fallback["source"]
            timezone_name = fallback.get("timezone")
        elif response.status_code != 200:
            logger.warning(
                "Open-Meteo water forecast failed: status=%s body=%s",
                response.status_code,
                response.text[:500].replace("\n", " "),
            )
            raise HTTPException(
                status_code=502,
                detail="Water forecast service returned an error.",
            )
        else:
            try:
                body = response.json()
                raw_daily = body["daily"]
            except (ValueError, KeyError, TypeError) as exc:
                raise HTTPException(
                    status_code=502,
                    detail="Water forecast returned an invalid response.",
                ) from exc

            daily = []
            for i, date in enumerate(raw_daily.get("time", [])):
                def get_value(key: str) -> Any:
                    values = raw_daily.get(key) or []
                    return values[i] if i < len(values) else None

                daily.append({
                    "date": date,
                    "precipitation_mm": get_value("precipitation_sum"),
                    "precipitation_probability_percent": get_value(
                        "precipitation_probability_max"
                    ),
                    "et0_mm": get_value("et0_fao_evapotranspiration"),
                    "temperature_mean_c": get_value("temperature_2m_mean"),
                })

            source = "Open-Meteo Forecast API"
            timezone_name = body.get("timezone")

    except HTTPException:
        raise
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail="Water forecast request failed.",
        ) from exc
    except Exception as exc:
        logger.warning("Unexpected water forecast failure: %s", type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="Water forecast request failed.",
        ) from exc

    def total(key):
        vals = [float(x[key]) for x in daily if x.get(key) is not None]
        return round(sum(vals), 2) if vals else None

    rain = total("precipitation_mm")
    et0 = total("et0_mm")
    probs = [
        float(x["precipitation_probability_percent"])
        for x in daily
        if x.get("precipitation_probability_percent") is not None
    ]
    max_prob = round(max(probs), 2) if probs else None
    atmospheric_balance = (
        round(rain - et0, 2)
        if rain is not None and et0 is not None
        else None
    )

    signals = []

    if rain is not None and et0 is not None and atmospheric_balance < 0:
        signals.append({
            "type": "forecast_water_balance",
            "status": "precipitation_below_reference_et0",
            "evidence": (
                f"Forecast precipitation is {rain:.1f} mm versus "
                f"reference ET0 of {et0:.1f} mm; difference "
                f"{atmospheric_balance:.1f} mm."
            ),
            "meaning": (
                "Atmospheric water input is below reference evaporative "
                "demand over the forecast window."
            ),
        })

    if max_prob is not None and max_prob >= 70:
        signals.append({
            "type": "rain_event_probability",
            "status": "elevated",
            "evidence": f"Maximum forecast precipitation probability is {max_prob:.0f}%.",
            "meaning": (
                "Use the forecast to time field checks; probability is "
                "not measured rainfall."
            ),
        })

    if rain == 0:
        signals.append({
            "type": "forecast_rainfall",
            "status": "zero_forecast_precipitation",
            "evidence": "Forecast precipitation totals are 0 mm for the requested window.",
        })

    return {
        "available": True,
        "source": source,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "coordinates": {"latitude": r.latitude, "longitude": r.longitude},
        "timezone": timezone_name,
        "forecast_days": len(daily),
        "summary": {
            "forecast_precipitation_mm": rain,
            "reference_et0_mm": et0,
            "precipitation_minus_reference_et0_mm": atmospheric_balance,
            "maximum_precipitation_probability_percent": max_prob,
        },
        "signals": signals,
        "daily": daily,
        "decision_support": [
            "Do not convert this atmospheric balance into an irrigation volume without measured field soil moisture, crop water requirements, effective rainfall, and irrigation-system information.",
            "Check actual soil moisture in the field before deciding whether irrigation is required.",
            "After rainfall, verify infiltration and field conditions rather than assuming all forecast precipitation became root-zone water.",
        ],
        "limitations": [
            "Reference ET0 is atmospheric demand for a reference surface, not crop evapotranspiration.",
            "Forecast precipitation is not the same as effective root-zone rainfall.",
            "No soil-moisture sensor or farm irrigation-system measurement is used by this endpoint.",
        ],
    }
