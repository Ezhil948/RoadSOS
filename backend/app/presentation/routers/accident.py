"""Accident router — report submission and retrieval."""
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from app.utils.database import get_db
from app.models.schemas import StatusUpdate
from typing import Optional
from app.infrastructure.repositories.accident_repository import AccidentRepository
from app.use_cases.accident_usecase import AccidentUseCase

router = APIRouter()

# Maximum image size: 10 MB
_MAX_IMAGE_BYTES = 10 * 1024 * 1024

@router.post("/report", summary="Submit an accident report")
async def report_accident(
    background_tasks: BackgroundTasks,
    latitude: float = Form(...),
    longitude: float = Form(...),
    severity: str = Form("moderate"),
    casualties: int = Form(0),
    description: Optional[str] = Form(None),
    citizen_name: Optional[str] = Form(None),
    citizen_phone: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
):
    file_bytes = None
    filename = None
    content_type = None
    if image and image.filename:
        file_bytes = await image.read()
        if len(file_bytes) > _MAX_IMAGE_BYTES:
            raise HTTPException(413, "Image exceeds 10 MB limit")
        filename = image.filename
        content_type = image.content_type

    repo = AccidentRepository(db)
    use_case = AccidentUseCase(repo)
    return await use_case.submit_report(
        background_tasks, latitude, longitude, severity, casualties, description, file_bytes, filename, content_type, citizen_name, citizen_phone
    )

@router.get("/reports", summary="List accident reports")
async def list_reports(
    status: Optional[str] = None,
    severity: Optional[str] = None,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
):
    repo = AccidentRepository(db)
    use_case = AccidentUseCase(repo)
    return await use_case.list_reports(status, severity, limit)

@router.get("/reports/{report_id}", summary="Get a specific accident report")
async def get_report(report_id: int, db: AsyncSession = Depends(get_db)):
    repo = AccidentRepository(db)
    use_case = AccidentUseCase(repo)
    result = await use_case.get_report(report_id)
    if not result:
        raise HTTPException(404, "Report not found")
    return result

@router.patch("/reports/{report_id}/status", summary="Update accident report status")
async def update_report_status(report_id: int, payload: StatusUpdate, db: AsyncSession = Depends(get_db)):
    repo = AccidentRepository(db)
    use_case = AccidentUseCase(repo)
    result = await use_case.update_report_status(report_id, payload.status)
    
    if "error" in result:
        if result["error"] == "invalid_status":
            raise HTTPException(400, f"Invalid status. Choose: {result['members']}")
        elif result["error"] == "not_found":
            raise HTTPException(404, "Report not found")
            
    return result
