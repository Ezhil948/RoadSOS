"""SOS router — emergency alert trigger and management."""
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.sql import func
from app.utils.database import get_db
from app.utils.geo import haversine_km
from app.models.db_models import SOSAlert, AppLog
from app.models.schemas import SOSRequest, SOSResponse, ResolveRequest
from pydantic import BaseModel
from typing import Optional, List
import json, httpx, os
from datetime import datetime, timezone, timedelta

router = APIRouter()

from app.routers.dispatch import trigger_dispatch

IMGBB_API_KEY = os.getenv("IMGBB_API_KEY")

class LocationUpdateRequest(BaseModel):
    new_lat: float
    new_lng: float
    citizen_device_id: str

class LocationPatchRequest(BaseModel):
    lat: float
    lng: float

class CloseIncidentRequest(BaseModel):
    officer_notes: Optional[str] = None
    photos: Optional[List[str]] = None


@router.post("/alert", response_model=SOSResponse, summary="Trigger SOS emergency alert")
async def send_sos_alert(payload: SOSRequest, db: AsyncSession = Depends(get_db)):
    if payload.device_id:
        # 1. Cooldown Check (150 seconds)
        cutoff_time = datetime.now(timezone.utc) - timedelta(seconds=150)
        recent_query = select(SOSAlert).where(
            SOSAlert.device_id == payload.device_id,
            SOSAlert.alerted_at >= cutoff_time
        ).order_by(SOSAlert.alerted_at.desc()).limit(1)
        recent_result = await db.execute(recent_query)
        recent_alert = recent_result.scalar_one_or_none()
        
        if recent_alert:
            if recent_alert.alerted_at.tzinfo is None:
                alert_time = recent_alert.alerted_at.replace(tzinfo=timezone.utc)
            else:
                alert_time = recent_alert.alerted_at
            elapsed = (datetime.now(timezone.utc) - alert_time).total_seconds()
            remaining = int(max(0, 150 - elapsed))
            if remaining > 0:
                raise HTTPException(status_code=429, detail={"error": "cooldown", "remaining_seconds": remaining})
                
    # 2. Duplicate Suppression (Merge into existing within 200m)
    import math
    # 0.5km bounding box to limit DB records fetched
    bb_lat = 0.5 / 111.0
    bb_lng = 0.5 / (111.0 * math.cos(math.radians(payload.latitude)))
    
    active_query = select(SOSAlert).where(
        SOSAlert.status == "active",
        SOSAlert.latitude.between(payload.latitude - bb_lat, payload.latitude + bb_lat),
        SOSAlert.longitude.between(payload.longitude - bb_lng, payload.longitude + bb_lng)
    )
    active_result = await db.execute(active_query)
    active_alerts = active_result.scalars().all()
    
    for existing_alert in active_alerts:
        dist_km = haversine_km(existing_alert.latitude, existing_alert.longitude, payload.latitude, payload.longitude)
        if dist_km <= 0.2:  # 200m
            # Merge
            reps = list(existing_alert.reporters) if existing_alert.reporters else []
            reps.append({"device_id": payload.device_id})
            existing_alert.reporters = reps
            await db.flush()
            
            return SOSResponse(
                status="merged",
                alert_id=existing_alert.id,
                message="Help is already on the way for this location.",
                nearest_emergency="112",
                action="CALL_112",
            )

    alert = SOSAlert(
        latitude=payload.latitude,
        longitude=payload.longitude,
        severity=payload.severity,
        message=payload.message,
        device_id=payload.device_id,
        status="active",
    )
    db.add(alert)

    db.add(AppLog(
        event_type="SOS_TRIGGERED",
        latitude=payload.latitude,
        longitude=payload.longitude,
        device_id=payload.device_id,
        log_metadata=json.dumps({"severity": payload.severity}),
    ))

    await db.flush()
    await db.refresh(alert)
    
    # Auto-trigger dispatch
    await trigger_dispatch(alert.id, db)

    return SOSResponse(
        status="received",
        alert_id=alert.id,
        message=f"SOS #{alert.id} recorded. Call 112 immediately.",
        nearest_emergency="112",
        action="CALL_112",
    )


@router.get("/alerts", summary="List all SOS alerts")
async def list_sos_alerts(
    status: Optional[str] = None,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
):
    # Filter BEFORE limit so we get the correct result set
    query = select(SOSAlert)
    if status:
        query = query.where(SOSAlert.status == status)
    query = query.order_by(SOSAlert.alerted_at.desc()).limit(limit)

    result = await db.execute(query)
    alerts = result.scalars().all()
    return {
        "total": len(alerts),
        "alerts": [
            {
                "id": a.id,
                "lat": a.latitude,
                "lng": a.longitude,
                "severity": a.severity,
                "status": a.status,
                "message": a.message,
                "alerted_at": str(a.alerted_at),
            }
            for a in alerts
        ],
        ],
    }


@router.get("/alerts/{alert_id}/status", summary="Poll alert status and assigned officer")
async def get_alert_status(alert_id: int, db: AsyncSession = Depends(get_db)):
    from app.routers.dispatch import _accepted_dispatches, _active_dispatches
    from app.models.db_models import Officer, SOSAlert
    from app.utils.geo import haversine_km

    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    
    if not alert:
        raise HTTPException(404, "Alert not found")
        
    response = {
        "status": alert.status, # "active", "resolved", "false_alarm", "cancelled"
        "is_dispatched": False,
        "officer": None
    }
    
    if alert.status == "active":
        if alert_id in _accepted_dispatches:
            response["is_dispatched"] = True
            officer_id = _accepted_dispatches[alert_id]
            
            # Get officer location
            off_res = await db.execute(select(Officer).where(Officer.id == officer_id))
            officer = off_res.scalar_one_or_none()
            
            if officer and officer.latitude and officer.longitude:
                dist = haversine_km(officer.latitude, officer.longitude, alert.latitude, alert.longitude)
                response["officer"] = {
                    "id": officer.id,
                    "badge": officer.badge_number,
                    "distance_km": round(dist, 2),
                    "eta_mins": int(dist * 2) # approx
                }
        elif alert_id not in _active_dispatches:
            # Not in active broadcast, not accepted -> maybe no officers available?
            # We'll just say it's active.
            pass

    return response@router.patch("/alerts/{alert_id}/resolve", summary="Resolve an SOS alert")
async def resolve_alert(alert_id: int, payload: Optional[ResolveRequest] = None, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(404, f"Alert {alert_id} not found")
    alert.status = "resolved"
    alert.resolved_at = func.now()

    notes = payload.officer_notes if payload else None
    db.add(AppLog(
        event_type="SOS_RESOLVED",
        log_metadata=json.dumps({"alert_id": alert_id, "officer_notes": notes})
    ))

    from app.routers.dispatch import _accepted_dispatches
    _accepted_dispatches.pop(alert_id, None)

    return {"status": "ok", "alert_id": alert_id, "message": "Alert resolved"}


@router.patch("/alerts/{alert_id}/false_alarm", summary="Mark SOS as false alarm and drop trust score")
async def mark_false_alarm(alert_id: int, payload: Optional[ResolveRequest] = None, db: AsyncSession = Depends(get_db)):
    from app.models.db_models import DeviceTrust
    
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(404, "Alert not found")
        
    alert.status = "false_alarm"
    alert.resolved_at = func.now()
    
    notes = payload.officer_notes if payload else None
    db.add(AppLog(
        event_type="SOS_FALSE_ALARM",
        log_metadata=json.dumps({"alert_id": alert_id, "officer_notes": notes})
    ))

    if alert.device_id:
        trust_result = await db.execute(select(DeviceTrust).where(DeviceTrust.device_id == alert.device_id))
        trust = trust_result.scalar_one_or_none()
        if not trust:
            trust = DeviceTrust(device_id=alert.device_id, trust_score=100)
            db.add(trust)
            
        trust.trust_score = max(0, trust.trust_score - 50)
        trust.false_alarms_count += 1
        
    return {"status": "ok", "message": "Marked as false alarm. Device trust score penalized."}


@router.post("/alerts/{alert_id}/cancel", summary="Citizen cancels their own SOS within the grace period")
async def cancel_sos_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    """
    Called by the citizen app when the user taps Cancel within 10 seconds.
    Sets the alert to 'cancelled' and releases any assigned officers back to available.
    """
    from app.routers.dispatch import _active_dispatches, _officer_alert_map

    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(404, f"Alert {alert_id} not found")
    if alert.status != "active":
        raise HTTPException(400, f"Alert {alert_id} is already {alert.status}")

    alert.status = "cancelled"
    alert.resolved_at = func.now()

    # Release any officers assigned to this dispatch
    dispatch_info = _active_dispatches.pop(alert_id, None)
    if dispatch_info:
        for oid in dispatch_info.get("officer_ids", []):
            _officer_alert_map.pop(oid, None)

    db.add(AppLog(
        event_type="SOS_CANCELLED",
        log_metadata=json.dumps({"alert_id": alert_id, "reason": "citizen_cancelled_within_grace_period"})
    ))

    return {"status": "ok", "alert_id": alert_id, "message": "SOS cancelled. Officers have been stood down."}


@router.post("/alerts/{alert_id}/location-update", summary="Suggest location change mid-dispatch")
async def suggest_location_update(alert_id: int, payload: LocationUpdateRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    
    if not alert:
        raise HTTPException(404, "Alert not found")
    
    # Amendment 3: Enforce ownership
    if alert.device_id and payload.citizen_device_id != alert.device_id:
        raise HTTPException(403, "Only original reporter can update location")

    # In MVP, officers might not hit "dispatched" state explicitly or maybe we consider "active" and "pending".
    # For now, if the alert is active or dispatched, allow it.
    dist_km = haversine_km(alert.latitude, alert.longitude, payload.new_lat, payload.new_lng)
    if dist_km <= 0.2:
        raise HTTPException(400, "no_significant_change")

    alert.location_update_pending = True
    alert.new_lat = payload.new_lat
    alert.new_lng = payload.new_lng
    await db.flush()
    return {"status": "pending_officer_approval"}


@router.post("/alerts/{alert_id}/location-update/confirm", summary="Officer confirms location change")
async def confirm_location_update(alert_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert or not alert.location_update_pending:
        raise HTTPException(404, "Update not found or already processed")
        
    alert.latitude = alert.new_lat
    alert.longitude = alert.new_lng
    alert.location_update_pending = False
    alert.new_lat = None
    alert.new_lng = None
    await db.flush()
    return {"status": "ok"}


@router.post("/alerts/{alert_id}/location-update/dismiss", summary="Officer dismisses location change")
async def dismiss_location_update(alert_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert or not alert.location_update_pending:
        raise HTTPException(404, "Update not found")
        
    alert.location_update_pending = False
    alert.new_lat = None
    alert.new_lng = None
    await db.flush()
    return {"status": "ok"}


@router.patch("/alerts/{alert_id}", summary="Re-SOS update location")
async def patch_alert_location(alert_id: int, payload: LocationPatchRequest, db: AsyncSession = Depends(get_db)):
    # This resets the status to pending/active and re-dispatches
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(404, "Alert not found")
        
    alert.latitude = payload.lat
    alert.longitude = payload.lng
    alert.status = "active"
    await db.flush()
    
    await trigger_dispatch(alert.id, db)
    return {"status": "ok", "message": "Location updated and re-dispatched"}


@router.post("/alerts/{alert_id}/close", summary="Close incident with evidence")
async def close_incident(alert_id: int, payload: CloseIncidentRequest, db: AsyncSession = Depends(get_db)):
    import base64
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(404, "Alert not found")
        
    alert.status = "resolved"
    alert.resolved_at = func.now()
    
    if payload.officer_notes:
        alert.closure_notes = payload.officer_notes
        
    photo_urls = []
    if payload.photos:
        async with httpx.AsyncClient(timeout=30.0) as client:
            for idx, b64_str in enumerate(payload.photos):
                try:
                    # Some base64 strings come with data URI headers like data:image/jpeg;base64,
                    if "," in b64_str:
                        b64_str = b64_str.split(",")[1]
                    file_bytes = base64.b64decode(b64_str)
                    files = {"image": (f"incident_{alert_id}_{idx}.jpg", file_bytes, "image/jpeg")}
                    res = await client.post(f"https://api.imgbb.com/1/upload?key={IMGBB_API_KEY}", files=files)
                    if res.status_code == 200:
                        url = res.json().get("data", {}).get("url")
                        if url:
                            photo_urls.append(url)
                except Exception as e:
                    print(f"ImgBB upload error: {e}")
                    
    alert.closure_photo_urls = photo_urls
    await db.flush()
    
    # We should update officer status back to available, but we don't have officer_id in payload.
    # The officer's dispatch action /officers/{officer_id}/ping will set it back anyway if they go online.
    db.add(AppLog(
        event_type="INCIDENT_CLOSED",
        log_metadata=json.dumps({"alert_id": alert_id, "photos": len(photo_urls)})
    ))
    
    from app.routers.dispatch import _accepted_dispatches
    _accepted_dispatches.pop(alert_id, None)
    
    return {"status": "ok"}


