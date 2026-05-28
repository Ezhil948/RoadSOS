"""Logs router — app event audit and analytics."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import AppLog
from pydantic import BaseModel
from typing import Optional
import json

router = APIRouter()


class LogIn(BaseModel):
    event_type: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    device_id: Optional[str] = None
    metadata: Optional[dict] = None


@router.post("/event", summary="Log an app event")
async def log_event(payload: LogIn, db: AsyncSession = Depends(get_db)):
    log = AppLog(
        event_type=payload.event_type,
        latitude=payload.latitude,
        longitude=payload.longitude,
        device_id=payload.device_id,
        log_metadata=json.dumps(payload.metadata) if payload.metadata else None,
    )
    db.add(log)
    return {"status": "logged"}


@router.get("/recent", summary="Get recent app logs")
async def recent_logs(limit: int = 50, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(AppLog).order_by(AppLog.logged_at.desc()).limit(limit)
    )
    logs = result.scalars().all()
    return {
        "total": len(logs),
        "logs": [
            {
                "id": log.id,
                "event": log.event_type,
                "lat": log.latitude,
                "lng": log.longitude,
                "at": str(log.logged_at),
            }
            for log in logs
        ],
    }
