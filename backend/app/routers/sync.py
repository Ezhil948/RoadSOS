"""Sync router — pre-fetch services for offline caching."""
import asyncio
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.utils.database import get_db
from app.services.osm_service import fetch_nearby_from_osm

router = APIRouter()

OFFLINE_TYPES = ["police", "hospital", "ambulance"]


@router.get("/offline-data", summary="Pre-fetch all critical services for offline cache")
async def get_offline_bundle(
    lat: float,
    lng: float,
    db: AsyncSession = Depends(get_db),
):
    """Fetch all critical service types in parallel (3× faster than sequential)."""

    async def _fetch_safe(service_type: str):
        try:
            places = await fetch_nearby_from_osm(lat, lng, service_type, radius=10000)
            return service_type, places
        except Exception:
            return service_type, []

    # Parallel fetch — all three requests fire concurrently
    results = await asyncio.gather(*[_fetch_safe(t) for t in OFFLINE_TYPES])
    bundle = dict(results)

    return {
        "status": "ok",
        "bundle": bundle,
        "types_synced": OFFLINE_TYPES,
        "note": "Cache this response in Hive for offline use",
    }
