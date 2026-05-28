"""SOS router — emergency alert trigger and management."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.sql import func
from app.utils.database import get_db
from app.models.db_models import SOSAlert, AppLog
from app.models.schemas import SOSRequest, SOSResponse, ResolveRequest
from typing import Optional
import json

router = APIRouter()

from app.routers.dispatch import trigger_dispatch

@router.post("/alert", response_model=SOSResponse, summary="Trigger SOS emergency alert")
async def send_sos_alert(payload: SOSRequest, db: AsyncSession = Depends(get_db)):
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
    }


@router.patch("/alerts/{alert_id}/resolve", summary="Resolve an SOS alert")
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
