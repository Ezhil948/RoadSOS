"""Dispatch router — Presentation Layer (Clean Architecture).
All officer endpoints require JWT authentication (Finding #2).
WebSocket requires token query param verified BEFORE accept (Finding #3).
"""
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from app.utils.database import get_db
from app.models.schemas import LocationPing, DispatchResponse, OfficerBackupRequest
from app.infrastructure.repositories.dispatch_repository import DispatchRepository
from app.use_cases.dispatch_usecase import DispatchUseCase
from app.utils.security import get_current_officer, verify_token

router = APIRouter()
from app.utils.websocket_manager import manager

def get_dispatch_usecase(db: AsyncSession = Depends(get_db)) -> DispatchUseCase:
    repo = DispatchRepository(db)
    return DispatchUseCase(repo)

@router.post("/officers/{officer_id}/ping", summary="Update officer live location and status")
async def ping_location(
    officer_id: int, 
    payload: LocationPing, 
    current_officer_id: int = Depends(get_current_officer),
    usecase: DispatchUseCase = Depends(get_dispatch_usecase)
):
    if officer_id != current_officer_id:
        raise HTTPException(status_code=403, detail="You can only ping your own location")
    result = await usecase.ping_location(officer_id, payload.latitude, payload.longitude, payload.status)
    if "error" in result:
        raise HTTPException(status_code=result["status_code"], detail=result["error"])
    return result

@router.get("/officers/{officer_id}/dispatch", summary="Poll for incoming dispatch (Uber screen)")
async def poll_dispatch(
    officer_id: int, 
    current_officer_id: int = Depends(get_current_officer),
    usecase: DispatchUseCase = Depends(get_dispatch_usecase)
):
    """Officer app polls this every 2 seconds to see if they have an active dispatch request."""
    if officer_id != current_officer_id:
        raise HTTPException(status_code=403, detail="You can only poll your own dispatch")
    return await usecase.poll_dispatch(officer_id)

@router.post("/officers/{officer_id}/dispatch/{alert_id}", summary="Accept or reject a dispatch")
async def respond_to_dispatch(
    officer_id: int, 
    alert_id: int, 
    payload: DispatchResponse, 
    current_officer_id: int = Depends(get_current_officer),
    usecase: DispatchUseCase = Depends(get_dispatch_usecase)
):
    if officer_id != current_officer_id:
        raise HTTPException(status_code=403, detail="You can only respond to your own dispatch")
    result = await usecase.respond_to_dispatch(officer_id, alert_id, payload.action)
    if "error" in result:
        raise HTTPException(status_code=result["status_code"], detail=result["error"])
    return result

@router.post("/trigger/{alert_id}", summary="System endpoint to find nearest officer")
async def trigger_dispatch(alert_id: int, usecase: DispatchUseCase = Depends(get_dispatch_usecase)):
    """Called by the SOS endpoint to find the nearest available officer."""
    result = await usecase.find_and_assign_officers(alert_id)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result.get("message", "Error finding officers"))
    return result

# Expose internal helper for sos.py backward compatibility (since sos.py isn't fully refactored yet)
async def trigger_dispatch_internal(alert_id: int, db: AsyncSession):
    repo = DispatchRepository(db)
    usecase = DispatchUseCase(repo)
    result = await usecase.find_and_assign_officers(alert_id)
    await repo.commit()
    return result

@router.post("/officers/{officer_id}/backup", summary="Officer requests backup")
async def request_backup(
    officer_id: int, 
    payload: OfficerBackupRequest, 
    current_officer_id: int = Depends(get_current_officer),
    usecase: DispatchUseCase = Depends(get_dispatch_usecase)
):
    if officer_id != current_officer_id:
        raise HTTPException(status_code=403, detail="You can only request backup for yourself")
    result = await usecase.request_backup(officer_id, payload.latitude, payload.longitude, payload.message)
    if "error" in result:
        raise HTTPException(status_code=result["status_code"], detail=result["error"])
    return result

@router.websocket("/ws/officer/{officer_id}")
async def websocket_endpoint(websocket: WebSocket, officer_id: int):
    # SECURITY FIX (Finding #3): Verify JWT token BEFORE accepting the WebSocket connection
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4001, reason="Missing authentication token")
        return
    try:
        payload = verify_token(token)
        token_officer_id = int(payload["sub"])
        if token_officer_id != officer_id:
            await websocket.close(code=4003, reason="Officer ID mismatch")
            return
    except Exception:
        await websocket.close(code=4001, reason="Invalid or expired token")
        return

    await manager.connect(officer_id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(officer_id, websocket)
