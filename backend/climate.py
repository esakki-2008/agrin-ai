from typing import Any

import logging
from collections import defaultdict
from datetime import datetime, timezone

import httpx
from data_sources import _get_http_client
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/climate", tags=["Climate & Weather Intelligence"])
logger = logging.getLogger(__name__)


class ClimateRequest(BaseModel):
    latitude: float
    longitude: float
    forecast_days: int = 7


def _validate(request: ClimateRequest) -> None:
    if not (-90 <= request.latitude <= 90 and -180 <= request.longitude <= 180):
        raise HTTPException(status_code=400, detail="Invalid coordinates.")
    if not 1 <= request.forecast_days <= 16:
        raise HTTPException(status_code=400, detail="forecast_days must be between 1 and 16.")


async def _fetch_met_norway_forecast(
    client: httpx.AsyncClient,
    latitude: float,
    longitude: float,
    forecast_days: int,
) -> dict[str, Any]:
    url = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
    params = {
        "lat": round(latitude, 4),
        "lon": round(longitude, 4),
    }
    headers = {
        "User-Agent": "AgriN-AI/1.0 (https://github.com/esakki-2008/agrin-ai)",
    }

    try:
        response = await client.get(
            url,
            params=params,
            headers=headers,
            timeout=30,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail="Climate forecast request failed.",
        ) from exc

    if response.status_code != 200:
        logger.warning(
            "MET Norway forecast failed: status=%s body=%s",
            response.status_code,
            response.text[:500].replace("\n", " "),
        )
        raise HTTPException(
            status_code=502,
            detail="Climate forecast service returned an error.",
        )

    try:
        payload = response.json()
        timeseries = payload["properties"]["timeseries"]
    except (ValueError, KeyError, TypeError) as exc:
        raise HTTPException(
            status_code=502,
            detail="Climate forecast returned an invalid response.",
        ) from exc

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)

    for item in timeseries:
        timestamp = item.get("time")
        if not timestamp:
            continue
        try:
            day = datetime.fromisoformat(
                timestamp.replace("Z", "+00:00")
            ).date().isoformat()
        except ValueError:
            continue
        grouped[day].append(item)

    rows: list[dict[str, Any]] = []
    for day in sorted(grouped)[:forecast_days]:
        items = grouped[day]
        temperatures: list[float] = []
        precipitation: list[float] = []
        wind: list[float] = []
        rain_prob: list[float] = []
        symbols: list[str] = []

        for item in items:
            details = (
                item.get("data", {})
                .get("instant", {})
                .get("details", {})
            )
            if details.get("air_temperature") is not None:
                temperatures.append(float(details["air_temperature"]))
            if details.get("wind_speed") is not None:
                wind.append(float(details["wind_speed"]) * 3.6)

            for period_key in ("next_1_hours", "next_6_hours"):
                period = item.get("data", {}).get(period_key, {})
                period_details = period.get("details", {})
                if period_details.get("precipitation_amount") is not None:
                    precipitation.append(
                        float(period_details["precipitation_amount"])
                    )
                if period_details.get("probability_of_precipitation") is not None:
                    rain_prob.append(
                        float(period_details["probability_of_precipitation"])
                    )
                symbol = period.get("summary", {}).get("symbol_code")
                if symbol:
                    symbols.append(symbol)

        rows.append({
            "date": day,
            "temperature_mean_c": (
                round(sum(temperatures) / len(temperatures), 2)
                if temperatures else None
            ),
            "temperature_max_c": round(max(temperatures), 2) if temperatures else None,
            "temperature_min_c": round(min(temperatures), 2) if temperatures else None,
            "precipitation_mm": round(sum(precipitation), 2) if precipitation else 0.0,
            "precipitation_probability_percent": (
                round(max(rain_prob), 2) if rain_prob else None
            ),
            "wind_max_kmh": round(max(wind), 2) if wind else None,
            "et0_mm": None,
            "weather_code": symbols[0] if symbols else None,
        })

    if not rows:
        raise HTTPException(
            status_code=502,
            detail="Climate forecast returned no usable data.",
        )

    daily: dict[str, list[Any]] = {
        "time": [row["date"] for row in rows],
        "temperature_2m_mean": [row["temperature_mean_c"] for row in rows],
        "temperature_2m_max": [row["temperature_max_c"] for row in rows],
        "temperature_2m_min": [row["temperature_min_c"] for row in rows],
        "precipitation_sum": [row["precipitation_mm"] for row in rows],
        "precipitation_probability_max": [
            row["precipitation_probability_percent"] for row in rows
        ],
        "wind_speed_10m_max": [row["wind_max_kmh"] for row in rows],
        "et0_fao_evapotranspiration": [row["et0_mm"] for row in rows],
        "weather_code": [row["weather_code"] for row in rows],
    }

    return {
        "available": True,
        "source": "MET Norway Locationforecast",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "coordinates": {
            "latitude": latitude,
            "longitude": longitude,
        },
        "timezone": "UTC",
        "forecast_days": len(rows),
        "daily": daily,
    }


@router.post("/intelligence")
async def climate_intelligence(request: ClimateRequest):
    _validate(request)

    daily_fields = ",".join([
        "temperature_2m_mean",
        "temperature_2m_max",
        "temperature_2m_min",
        "precipitation_sum",
        "precipitation_probability_max",
        "wind_speed_10m_max",
        "et0_fao_evapotranspiration",
        "weather_code",
    ])

    params = {
        "latitude": request.latitude,
        "longitude": request.longitude,
        "forecast_days": request.forecast_days,
        "daily": daily_fields,
        "timezone": "auto",
    }

    try:
        client = await _get_http_client()
        response = await _fetch_forecast(client, params)

        if response.status_code == 429:
            logger.warning("Open-Meteo quota exhausted; using MET Norway fallback.")
            body = await _fetch_met_norway_forecast(
                client,
                request.latitude,
                request.longitude,
                request.forecast_days,
            )
            daily = body["daily"]
        else:
            if response.status_code != 200:
                fallback_params = {
                    "latitude": request.latitude,
                    "longitude": request.longitude,
                    "forecast_days": request.forecast_days,
                    "daily": ",".join([
                        "temperature_2m_max",
                        "temperature_2m_min",
                        "precipitation_sum",
                        "wind_speed_10m_max",
                        "weather_code",
                    ]),
                    "timezone": "auto",
                }
                response = await _fetch_forecast(client, fallback_params)

            if response.status_code != 200:
                logger.warning(
                    "Open-Meteo forecast failed: status=%s body=%s",
                    response.status_code,
                    response.text[:500].replace("\\n", " "),
                )
                raise HTTPException(
                    status_code=502,
                    detail="Climate forecast service returned an error.",
                )

            try:
                body = response.json()
                daily = body["daily"]
            except (ValueError, KeyError, TypeError) as exc:
                raise HTTPException(
                    status_code=502,
                    detail="Climate forecast returned an invalid response.",
                ) from exc
    except HTTPException:
        raise
    except httpx.HTTPError as exc:
        logger.warning("Climate forecast transport failure: %s", type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="Climate forecast request failed.",
        ) from exc
    except Exception as exc:
        logger.exception("Climate forecast unexpected failure: %s", type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="Climate forecast request failed.",
        ) from exc

    try:
        body = response.json()
        daily = body["daily"]
    except (ValueError, KeyError, TypeError) as exc:
        raise HTTPException(
            status_code=502,
            detail="Climate forecast returned an invalid response.",
        ) from exc

    times = daily.get("time", [])
    rows: list[dict[str, Any]] = []

    for i, day in enumerate(times):
        row: dict[str, Any] = {"date": day}

        def get_value(key: str) -> Any:
            values = daily.get(key) or []
            return values[i] if i < len(values) else None

        row["temperature_mean_c"] = get_value("temperature_2m_mean")
        row["temperature_max_c"] = get_value("temperature_2m_max")
        row["temperature_min_c"] = get_value("temperature_2m_min")
        row["precipitation_mm"] = get_value("precipitation_sum")
        row["precipitation_probability_percent"] = get_value(
            "precipitation_probability_max"
        )
        row["wind_max_kmh"] = get_value("wind_speed_10m_max")
        row["et0_mm"] = get_value("et0_fao_evapotranspiration")
        row["weather_code"] = get_value("weather_code")
        rows.append(row)

    def values(key: str) -> list[float]:
        return [
            float(r[key])
            for r in rows
            if r.get(key) is not None
        ]

    rain = values("precipitation_mm")
    et0 = values("et0_mm")
    highs = values("temperature_max_c")
    wind = values("wind_max_kmh")
    rain_prob = values("precipitation_probability_percent")

    total_rain = round(sum(rain), 2) if rain else None
    total_et0 = round(sum(et0), 2) if et0 else None
    max_temp = round(max(highs), 2) if highs else None
    max_wind = round(max(wind), 2) if wind else None
    max_rain_prob = round(max(rain_prob), 2) if rain_prob else None

    signals: list[dict[str, Any]] = []
    if max_temp is not None and max_temp >= 35:
        signals.append({
            "type": "heat",
            "status": "observed_in_forecast",
            "evidence": f"Forecast maximum temperature reaches {max_temp:.1f} °C.",
            "threshold_note": "35 °C is a screening threshold, not a crop-specific damage threshold.",
        })
    if max_rain_prob is not None and max_rain_prob >= 70:
        signals.append({
            "type": "rain_probability",
            "status": "elevated",
            "evidence": f"At least one forecast day has {max_rain_prob:.0f}% maximum precipitation probability.",
            "threshold_note": "This is a forecast probability, not a measured rainfall amount.",
        })
    if total_rain is not None and total_rain == 0:
        signals.append({
            "type": "rainfall",
            "status": "no_forecast_rain",
            "evidence": "Forecast precipitation totals are 0 mm for the requested window.",
        })
    if total_et0 is not None and total_rain is not None and total_et0 > total_rain:
        signals.append({
            "type": "atmospheric_water_demand",
            "status": "et0_above_forecast_rain",
            "evidence": f"Forecast reference ET0 totals {total_et0:.1f} mm versus {total_rain:.1f} mm precipitation.",
            "limitation": "ET0 is reference evapotranspiration, not crop water use or irrigation requirement.",
        })
    if max_wind is not None and max_wind >= 30:
        signals.append({
            "type": "wind",
            "status": "elevated",
            "evidence": f"Forecast maximum wind speed reaches {max_wind:.1f} km/h.",
            "threshold_note": "30 km/h is a screening threshold, not a crop-specific damage threshold.",
        })

    return {
        "available": True,
        "source": "Open-Meteo Forecast API",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "coordinates": {
            "latitude": request.latitude,
            "longitude": request.longitude,
        },
        "timezone": body.get("timezone"),
        "forecast_days": len(rows),
        "summary": {
            "total_forecast_precipitation_mm": total_rain,
            "total_reference_et0_mm": total_et0,
            "maximum_temperature_c": max_temp,
            "maximum_wind_kmh": max_wind,
            "maximum_precipitation_probability_percent": max_rain_prob,
        },
        "signals": signals,
        "daily": rows,
        "limitations": [
            "Forecast values can change as weather models update.",
            "Screening thresholds are not crop-specific agronomic thresholds.",
            "ET0 is reference evapotranspiration and does not equal crop water requirement.",
        ],
    }    try:
        client = await _get_http_client()
        response = await _fetch_forecast(client, params)

        if response.status_code == 429:
            logger.warning("Open-Meteo quota exhausted; using MET Norway fallback.")
            body = await _fetch_met_norway_forecast(
                client,
                request.latitude,
                request.longitude,
                request.forecast_days,
            )
            daily = body["daily"]
        else:
            if response.status_code != 200:
                fallback_params = {
                    "latitude": request.latitude,
                    "longitude": request.longitude,
                    "forecast_days": request.forecast_days,
                    "daily": ",".join([
                        "temperature_2m_max",
                        "temperature_2m_min",
                        "precipitation_sum",
                        "wind_speed_10m_max",
                        "weather_code",
                    ]),
                    "timezone": "auto",
                }
                response = await _fetch_forecast(client, fallback_params)

            if response.status_code != 200:
                logger.warning(
                    "Open-Meteo forecast failed: status=%s body=%s",
                    response.status_code,
                    response.text[:500].replace("\\n", " "),
                )
                raise HTTPException(
                    status_code=502,
                    detail="Climate forecast service returned an error.",
                )

            try:
                body = response.json()
                daily = body["daily"]
            except (ValueError, KeyError, TypeError) as exc:
                raise HTTPException(
                    status_code=502,
                    detail="Climate forecast returned an invalid response.",
                ) from exc
    except HTTPException:
        raise
    except httpx.HTTPError as exc:
        logger.warning("Climate forecast transport failure: %s", type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="Climate forecast request failed.",
        ) from exc
    except Exception as exc:
        logger.exception("Climate forecast unexpected failure: %s", type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="Climate forecast request failed.",
        ) from exc

