from datetime import datetime, timezone
import hashlib
import json
from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/network", tags=["AgriN Open Agricultural Network"])

class NetworkObservation(BaseModel):
    producer: str = "AgriN"
    observation: dict
    source_policy: str = "Source attribution required; share minimum necessary fields."

@router.get("/manifest")
async def manifest():
    return {
        "network": "AgriN Open Agricultural Network",
        "protocol_version": "1.0",
        "status": "federated-ready",
        "exchange": {
            "format": "JSON",
            "geometry": "WGS84 latitude/longitude",
            "transport": "HTTP API compatible",
            "identity": "No farmer identity required by the observation contract",
        },
        "capabilities": [
            "observation export",
            "observation validation",
            "source attribution",
            "machine-readable timestamps",
            "country-neutral codes",
            "privacy-aware field minimization",
        ],
        "data_principle": "AgriN exchanges observations; receiving systems remain responsible for local validation and policy.",
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }

@router.post("/package")
async def package_observation(payload: NetworkObservation):
    canonical = json.dumps(payload.observation, sort_keys=True, separators=(",", ":")).encode()
    digest = hashlib.sha256(canonical).hexdigest()
    return {
        "network": "AgriN Open Agricultural Network",
        "protocol_version": "1.0",
        "package_type": "agricultural-observation",
        "producer": payload.producer,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "observation_sha256": digest,
        "source_policy": payload.source_policy,
        "observation": payload.observation,
        "verification": {
            "integrity_hash": "SHA-256 over canonical observation JSON",
            "semantic_validation": "Use /interoperability/validate before accepting operationally.",
        },
        "limitations": [
            "This endpoint packages data but does not create a persistent public registry.",
            "No farmer identity or consent record is inferred.",
            "Receiving systems must apply their own governance, privacy and quality rules.",
        ],
    }
