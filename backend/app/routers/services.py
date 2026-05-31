"""Services router — nearby emergency service lookup with OSM + DB cache fallback."""
from fastapi import APIRouter, Query, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.dialects.mysql import insert as mysql_insert
from app.utils.database import get_db
from app.utils.geo import haversine_km
from app.models.db_models import CachedService, AppLog, ServiceTypeEnum
from app.services.osm_service import fetch_nearby_from_osm
from pydantic import BaseModel
from typing import List, Optional
import json

router = APIRouter()


class ServiceResult(BaseModel):
    id: str
    name: str
    type: str
    latitude: float
    longitude: float
    distance_km: float
    phone: Optional[str] = None
    address: Optional[str] = None
    is_open: bool = True
    is_cached: bool = False
    country_code: Optional[str] = None


class NearbyResponse(BaseModel):
    results: List[ServiceResult]
    total: int
    source: str  # "osm_live" | "db_cache"


@router.get("/nearby", response_model=NearbyResponse, summary="Get nearby emergency services")
async def get_nearby_services(
    lat: float = Query(..., description="User latitude"),
    lng: float = Query(..., description="User longitude"),
    type: str = Query("hospital", description="Service type: police|hospital|ambulance|towing|puncture|showroom"),
    radius: int = Query(15000, description="Radius in meters (max 30000)", le=30000),
    db: AsyncSession = Depends(get_db),
):
    # Validate against the enum instead of a hardcoded list
    if type not in ServiceTypeEnum.__members__:
        raise HTTPException(400, f"Invalid type. Choose: {list(ServiceTypeEnum.__members__)}")

    source = "osm_live"
    places: List[ServiceResult] = []

    # 1. Try OSM Overpass (live)
    try:
        raw = await fetch_nearby_from_osm(lat, lng, type, radius)
        places = [ServiceResult(**p) for p in raw]

        # 2. Batch upsert into cached_services for offline fallback (top 10)
        if raw[:10]:
            rows = [
                {
                    "osm_id": p["id"],
                    "name": p["name"],
                    "service_type": type,
                    "latitude": p["latitude"],
                    "longitude": p["longitude"],
                    "phone": p.get("phone"),
                    "address": p.get("address"),
                    "country_code": "IN",
                }
                for p in raw[:10]
            ]
            stmt = mysql_insert(CachedService).values(rows)
            stmt = stmt.on_duplicate_key_update(
                name=stmt.inserted.name,
                latitude=stmt.inserted.latitude,
                longitude=stmt.inserted.longitude,
                phone=stmt.inserted.phone,
                address=stmt.inserted.address,
            )
            await db.execute(stmt)

    except Exception:
        # 3. OSM failed — fall back to DB cache
        source = "db_cache"
        result = await db.execute(
            select(CachedService).where(
                CachedService.service_type == type,
                CachedService.is_active == True,
            ).limit(20)
        )
        rows_db = result.scalars().all()
        places = [
            ServiceResult(
                id=str(r.id),
                name=r.name,
                type=type,
                latitude=r.latitude,
                longitude=r.longitude,
                distance_km=round(haversine_km(lat, lng, r.latitude, r.longitude), 2),
                phone=r.phone,
                address=r.address,
                is_cached=True,
                country_code=r.country_code,
            )
            for r in rows_db
        ]
        places.sort(key=lambda p: p.distance_km)

    # Log the search event
    db.add(AppLog(
        event_type="NEARBY_SEARCH",
        latitude=lat,
        longitude=lng,
        log_metadata=json.dumps({"type": type, "radius": radius, "results": len(places)}),
    ))

    return NearbyResponse(results=places[:20], total=len(places), source=source)


@router.get("/types", summary="List available service types")
async def list_service_types():
    return {
        "types": [
            {"key": "police",    "label": "Police Station",   "icon": "🚔"},
            {"key": "hospital",  "label": "Hospital / Trauma","icon": "🏥"},
            {"key": "ambulance", "label": "Ambulance Service","icon": "🚑"},
            {"key": "towing",    "label": "Towing / Recovery","icon": "🚛"},
            {"key": "puncture",  "label": "Puncture Shop",    "icon": "🔧"},
            {"key": "showroom",  "label": "Car Showroom",     "icon": "🏪"},
        ]
    }
