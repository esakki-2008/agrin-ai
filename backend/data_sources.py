from datetime import datetime, timedelta, timezone
import io

import httpx

_http_client: httpx.AsyncClient | None = None


async def _get_http_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(
            follow_redirects=True,
            limits=httpx.Limits(
                max_connections=20,
                max_keepalive_connections=10,
                keepalive_expiry=30,
            ),
        )
    return _http_client


async def close_http_client() -> None:
    global _http_client
    if _http_client is not None and not _http_client.is_closed:
        await _http_client.aclose()
    _http_client = None
import rasterio
from fastapi import HTTPException


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


async def sample(
    property_name: str,
    coverage: str,
    lon: float,
    lat: float,
) -> float:
    url, params = wcs_url(property_name, coverage, lon, lat)

    client = await _get_http_client()
    response = await client.get(url, params=params, timeout=60)

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail="SoilGrids service returned an error.",
        )

    content_type = response.headers.get(
        "content-type",
        "",
    ).lower()

    if (
        "tiff" not in content_type
        and "image/" not in content_type
        and not response.content.startswith(b"II*\x00")
        and not response.content.startswith(b"MM\x00*")
    ):
        raise HTTPException(
            status_code=502,
            detail="SoilGrids returned an invalid raster response.",
        )

    try:
        with rasterio.open(
            io.BytesIO(response.content)
        ) as dataset:
            values = dataset.read(1, masked=True)
            data = values.compressed()
            data = data[data > 0]

            if len(data) == 0:
                raise ValueError(
                    "No valid SoilGrids pixels found "
                    "for this location."
                )

            return float(data.mean())

    except HTTPException:
        raise

    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail="Unable to process SoilGrids data.",
        ) from exc


async def find_satellite_scene(
    latitude: float,
    longitude: float,
    days: int,
    max_cloud_cover: float,
):
    stac_url = (
        "https://earth-search.aws.element84.com/v1/search"
    )

    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)

    payload = {
        "collections": ["sentinel-2-c1-l2a"],
        "datetime": (
            f"{start.isoformat().replace('+00:00', 'Z')}/"
            f"{now.isoformat().replace('+00:00', 'Z')}"
        ),
        "intersects": {
            "type": "Point",
            "coordinates": [longitude, latitude],
        },
        "limit": 50,
    }

    client = await _get_http_client()
    response = await client.post(stac_url, json=payload, timeout=30)

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=(
                "Satellite catalog returned HTTP "
                f"{response.status_code}."
            ),
        )

    features = response.json().get(
        "features",
        [],
    )

    candidates = []

    for feature in features:
        cloud = feature.get(
            "properties",
            {},
        ).get("eo:cloud_cover")

        if (
            cloud is not None
            and float(cloud) <= max_cloud_cover
        ):
            candidates.append(feature)

    candidates.sort(
        key=lambda feature: (
            feature.get("properties", {})
            .get("datetime")
            or ""
        ),
        reverse=True,
    )

    if not candidates:
        return None

    return candidates[0]