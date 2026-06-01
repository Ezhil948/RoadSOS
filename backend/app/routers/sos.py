"""SOS router — Presentation Layer (Clean Architecture)."""
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.schemas import SOSRequest, SOSResponse, ResolveRequest, CitizenCancelRequest, PoliceCancelRequest
from pydantic import BaseModel
from typing import Optional, List
import json, httpx, os, base64

from app.infrastructure.repositories.sos_repository import SOSRepository
from app.use_cases.sos_usecase import SOSUseCase
from app.routers.dispatch import trigger_dispatch_internal

router = APIRouter()
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

def get_sos_usecase(db: AsyncSession = Depends(get_db)) -> SOSUseCase:
    repo = SOSRepository(db)
    return SOSUseCase(repo, dispatch_trigger_fn=trigger_dispatch_internal)

@router.post("/alert", response_model=SOSResponse, summary="Trigger SOS emergency alert")
async def send_sos_alert(payload: SOSRequest, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.send_sos_alert(
        payload.latitude, payload.longitude, payload.severity, payload.message, payload.device_id
    )
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.get("/alerts", summary="List all SOS alerts")
async def list_sos_alerts(status: Optional[str] = None, limit: int = 50, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.list_sos_alerts(status, limit)
    await usecase.repo.commit()
    return result

@router.get("/alerts/{alert_id}/status", summary="Poll alert status and assigned officer")
async def get_alert_status(alert_id: int, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.get_alert_status(alert_id)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.patch("/alerts/{alert_id}/resolve", summary="Resolve an SOS alert")
async def resolve_alert(alert_id: int, payload: Optional[ResolveRequest] = None, usecase: SOSUseCase = Depends(get_sos_usecase)):
    notes = payload.officer_notes if payload else None
    result = await usecase.resolve_alert(alert_id, notes)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.patch("/alerts/{alert_id}/false_alarm", summary="Mark SOS as false alarm and drop trust score")
async def mark_false_alarm(alert_id: int, payload: Optional[ResolveRequest] = None, usecase: SOSUseCase = Depends(get_sos_usecase)):
    notes = payload.officer_notes if payload else None
    result = await usecase.mark_false_alarm(alert_id, notes)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.post("/alerts/{alert_id}/cancel", summary="Citizen cancels their own SOS within the grace period")
async def cancel_sos_alert(alert_id: int, payload: Optional[CitizenCancelRequest] = None, usecase: SOSUseCase = Depends(get_sos_usecase)):
    reason = payload.reason if payload else None
    result = await usecase.cancel_sos_alert(alert_id, reason)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.post("/alerts/{alert_id}/police-cancel", summary="Police cancels an SOS or Backup alert")
async def police_cancel_alert(alert_id: int, payload: PoliceCancelRequest, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.police_cancel_alert(alert_id, payload.reason, payload.details)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.post("/alerts/{alert_id}/location-update", summary="Suggest location change mid-dispatch")
async def suggest_location_update(alert_id: int, payload: LocationUpdateRequest, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.suggest_location_update(alert_id, payload.new_lat, payload.new_lng, payload.citizen_device_id)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.post("/alerts/{alert_id}/location-update/confirm", summary="Officer confirms location change")
async def confirm_location_update(alert_id: int, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.confirm_location_update(alert_id)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.post("/alerts/{alert_id}/location-update/dismiss", summary="Officer dismisses location change")
async def dismiss_location_update(alert_id: int, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.dismiss_location_update(alert_id)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.patch("/alerts/{alert_id}", summary="Re-SOS update location")
async def patch_alert_location(alert_id: int, payload: LocationPatchRequest, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.patch_alert_location(alert_id, payload.lat, payload.lng)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.post("/alerts/{alert_id}/close", summary="Close incident with evidence")
async def close_incident(alert_id: int, payload: CloseIncidentRequest, background_tasks: BackgroundTasks, usecase: SOSUseCase = Depends(get_sos_usecase)):
    result = await usecase.close_incident(alert_id, payload.officer_notes, payload.photos, background_tasks)
    if "error" in result:
        raise HTTPException(status_code=result.get("status_code", 400), detail=result["error"])
    
    await usecase.repo.commit()
    return result

@router.delete("/nuke", summary="Wipe all alerts and reports for fresh start")
async def nuke_database(db: AsyncSession = Depends(get_db)):
    from sqlalchemy import delete
    from app.models.db_models import SOSAlert, AccidentReport, AppLog, AIAnalysisResult
    await db.execute(delete(AIAnalysisResult))
    await db.execute(delete(SOSAlert))
    await db.execute(delete(AccidentReport))
    await db.execute(delete(AppLog))
    return {"status": "success", "message": "All emergency data nuked"}

# Background Task
async def upload_photos_task(alert_id: int, photos: List[str], db: AsyncSession):
    from app.models.db_models import SOSAlert
    try:
        photo_urls = []
        async with httpx.AsyncClient(timeout=30.0) as client:
            for idx, b64_str in enumerate(photos):
                try:
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
        
        if photo_urls:
            result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
            alert = result.scalar_one_or_none()
            if alert:
                alert.closure_photo_urls = photo_urls
                await db.commit()
    finally:
        await db.close()
