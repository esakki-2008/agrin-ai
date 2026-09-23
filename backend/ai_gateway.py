import asyncio
import json
import os
from typing import Any

import httpx

TRANSIENT_STATUS_CODES = {429, 500, 502, 503, 504}

_client: httpx.AsyncClient | None = None


class AIProviderError(Exception):
    """Raised when all configured Gemini providers fail."""


async def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(
            follow_redirects=True,
            limits=httpx.Limits(
                max_connections=20,
                max_keepalive_connections=10,
                keepalive_expiry=30,
            ),
        )
    return _client


async def close_client() -> None:
    global _client
    if _client is not None and not _client.is_closed:
        await _client.aclose()
    _client = None


def _providers() -> list[dict[str, str]]:
    providers: list[dict[str, str]] = []

    primary_key = os.getenv("GEMINI_API_KEY_PRIMARY") or os.getenv("GEMINI_API_KEY")
    primary_model = os.getenv("GEMINI_MODEL_PRIMARY", "gemini-2.5-flash")
    backup_key = os.getenv("GEMINI_API_KEY_BACKUP")
    backup_model = os.getenv("GEMINI_MODEL_BACKUP", "gemini-2.5-flash-lite")

    if primary_key:
        providers.append(
            {"name": "primary", "key": primary_key, "model": primary_model}
        )

    if backup_key:
        providers.append(
            {"name": "backup", "key": backup_key, "model": backup_model}
        )

    return providers


async def generate_json(
    prompt: str,
    *,
    temperature: float = 0.2,
    timeout: float = 45,
    image_base64: str | None = None,
    mime_type: str | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    providers = _providers()
    if not providers:
        raise AIProviderError("No Gemini API credentials are configured.")

    client = await _get_client()
    last_error = "Unknown Gemini error."

    for provider in providers:
        endpoint = (
            "https://generativelanguage.googleapis.com/"
            f"v1beta/models/{provider['model']}:generateContent"
        )
        parts: list[dict[str, Any]] = [{"text": prompt}]
        if image_base64 and mime_type:
            parts.append({
                "inline_data": {
                    "mime_type": mime_type,
                    "data": image_base64,
                }
            })

        payload = {
            "contents": [{"parts": parts}],
            "generationConfig": {
                "temperature": temperature,
                "responseMimeType": "application/json",
            },
        }

        for attempt in range(3):
            try:
                response = await client.post(
                    endpoint,
                    headers={
                        "x-goog-api-key": provider["key"],
                        "Content-Type": "application/json",
                    },
                    json=payload,
                    timeout=timeout,
                )

                if response.status_code == 200:
                    body = response.json()
                    text = body["candidates"][0]["content"]["parts"][0]["text"]
                    result = json.loads(text)
                    return result, {
                        "provider": provider["name"],
                        "model": provider["model"],
                        "attempt": attempt + 1,
                    }

                try:
                    error_message = response.json().get("error", {}).get(
                        "message",
                        "Gemini request failed.",
                    )
                except Exception:
                    error_message = (
                        f"Gemini returned HTTP {response.status_code}."
                    )

                last_error = error_message

                if response.status_code not in TRANSIENT_STATUS_CODES:
                    break

                if attempt < 2:
                    await asyncio.sleep(2**attempt)

            except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError) as exc:
                last_error = str(exc)
                if attempt < 2:
                    await asyncio.sleep(2**attempt)

    raise AIProviderError(
        f"All configured Gemini providers failed. Last error: {last_error}"
    )
