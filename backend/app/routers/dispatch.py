"""Dispatch router — Uber-style officer matching and alert distribution."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.sql import func
from app.utils.database import get_db
from app.utils.geo import haversine_km
from app.models.db_models import Officer, SOSAlert, DeviceTrust, AppLog
from app.models.schemas import LocationPing, DispatchResponse
from typing import Optional, List
import json

router = APIRouter()

# In-memory dispatch state for MVP
_active_dispatches: dict[int, dict] = {}       # alert_id → {"officer_ids": [...]}
_officer_alert_map: dict[int, int] = {}        # officer_id → alert_id  (inverted index)
_accepted_dispatches: dict[int, int] = {}      # alert_id → officer_id (assigned officer)


@router.post("/officers/{officer_id}/ping", summary="Update officer live location and status")
async def ping_location(officer_id: int, payload: LocationPing, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Officer).where(Officer.id == officer_id))
    officer = result.scalar_one_or_none()
    if not officer:
        raise HTTPException(404, "Officer not found")

    officer.latitude = payload.latitude
    officer.longitude = payload.longitude
    officer.status = payload.status
    officer.last_ping_at = func.now()
    
    await db.flush()
    return {"status": "ok"}


@router.get("/officers/{officer_id}/dispatch", summary="Poll for incoming dispatch (Uber screen)")
async def poll_dispatch(officer_id: int, db: AsyncSession = Depends(get_db)):
    """Officer app polls this every 2 seconds to see if they have an active dispatch request."""
    alert_id = _officer_alert_map.get(officer_id)
    if alert_id is None:
        return {"has_dispatch": False}
        
    # Fetch the alert details
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if alert and alert.status == "active":
        # Calculate distance
        officer = (await db.execute(select(Officer).where(Officer.id == officer_id))).scalar_one()
        dist = haversine_km(officer.latitude, officer.longitude, alert.latitude, alert.longitude)
        
        return {
            "has_dispatch": True,
            "dispatch": {
                "alert_id": alert.id,
                "latitude": alert.latitude,
                "longitude": alert.longitude,
                "severity": alert.severity,
                "distance_km": round(dist, 2),
                "eta_mins": int(dist * 2), # rough estimate 30km/h
                "message": alert.message or "Emergency SOS",
                "location_update_pending": alert.location_update_pending,
                "new_lat": alert.new_lat,
                "new_lng": alert.new_lng,
            }
        }
    else:
        # Alert resolved or cancelled, remove from dispatch
        _officer_alert_map.pop(officer_id, None)
        _active_dispatches.pop(alert_id, None)
        return {"has_dispatch": False}


@router.post("/officers/{officer_id}/dispatch/{alert_id}", summary="Accept or reject a dispatch")
async def respond_to_dispatch(
    officer_id: int, 
    alert_id: int, 
    payload: DispatchResponse, 
    db: AsyncSession = Depends(get_db)
):
    if alert_id not in _active_dispatches or officer_id not in _active_dispatches[alert_id].get("officer_ids", []):
        raise HTTPException(400, "Dispatch expired or not assigned to you")

    if payload.action == "accept":
        # Officer took it!
        result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
        alert = result.scalar_one_or_none()
        if alert:
            # We don't resolve it yet, it remains 'active' until the officer arrives and closes it
            alert.status = "active" 
            
        result_off = await db.execute(select(Officer).where(Officer.id == officer_id))
        officer = result_off.scalar_one()
        officer.status = "busy"
        
        _officer_alert_map.pop(officer_id, None)
        _active_dispatches.pop(alert_id, None)
        _accepted_dispatches[alert_id] = officer_id  # Track who took it
        
        db.add(AppLog(
            event_type="DISPATCH_ACCEPTED",
            log_metadata=json.dumps({"alert_id": alert_id, "officer_id": officer_id})
        ))
        return {"status": "accepted"}
        
    elif payload.action in ("reject", "missed"):
        # Officer rejected or missed it, remove them from the broadcast list
        _officer_alert_map.pop(officer_id, None)
        if officer_id in _active_dispatches[alert_id]["officer_ids"]:
            _active_dispatches[alert_id]["officer_ids"].remove(officer_id)
            
        if not _active_dispatches[alert_id]["officer_ids"]:
            _active_dispatches.pop(alert_id, None)
            
        db.add(AppLog(
            event_type=f"DISPATCH_{payload.action.upper()}",
            log_metadata=json.dumps({"alert_id": alert_id, "officer_id": officer_id})
        ))
        
        return {"status": payload.action}
        
    raise HTTPException(400, "Invalid action")


async def _find_and_assign_officers(alert_id: int, db: AsyncSession):
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert or not alert.latitude or not alert.longitude:
        return {"status": "error", "message": "Alert not found or invalid location"}

    # 1 degree lat ~ 111km. 50km ~ 0.45 degrees.
    import math
    lat_delta = 50.0 / 111.0
    lng_delta = 50.0 / (111.0 * math.cos(math.radians(alert.latitude)))

    # Fast 50km bounding box pre-filter query
    result_off = await db.execute(
        select(Officer).where(
            Officer.status == "available",
            Officer.latitude.between(alert.latitude - lat_delta, alert.latitude + lat_delta),
            Officer.longitude.between(alert.longitude - lng_delta, alert.longitude + lng_delta)
        )
    )
    officers = result_off.scalars().all()

    if not officers:
        return {"status": "no_officers"}

    # Calculate exact Haversine distance and sort
    scored = [
        (haversine_km(o.latitude, o.longitude, alert.latitude, alert.longitude), o)
        for o in officers if o.latitude and o.longitude
    ]

    if not scored:
        return {"status": "no_officers_with_location"}

    scored.sort(key=lambda x: x[0])
    
    # Cap dispatch broadcast to top 5 nearest officers
    top_officers = scored[:5]
    all_officer_ids = [o[1].id for o in top_officers]

    for oid in all_officer_ids:
        _officer_alert_map[oid] = alert_id
    _active_dispatches[alert_id] = {"officer_ids": all_officer_ids}

    return {
        "status": "dispatched",
        "officer_count": len(all_officer_ids),
        "officer_ids": all_officer_ids,
        "closest_distance_km": round(top_officers[0][0], 2),
    }


@router.post("/trigger/{alert_id}", summary="System endpoint to find nearest officer")
async def trigger_dispatch(alert_id: int, db: AsyncSession = Depends(get_db)):
    """Called by the SOS endpoint to find the nearest available officer."""
    return await _find_and_assign_officers(alert_id, db)
