"""Accident router — report submission and retrieval."""
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import AccidentReport, AppLog
from app.models.schemas import StatusUpdate
from typing import Optional
from pathlib import Path
import uuid, json, os
import httpx

router = APIRouter()

# Maximum image size: 10 MB
_MAX_IMAGE_BYTES = 10 * 1024 * 1024
IMGBB_API_KEY = os.getenv("IMGBB_API_KEY")

@router.post("/report", summary="Submit an accident report")
async def report_accident(
    latitude: float = Form(...),
    longitude: float = Form(...),
    severity: str = Form("moderate"),
    casualties: int = Form(0),
    description: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
):
    img_path: Optional[str] = None

    if image and image.filename:
        file_bytes = await image.read()
        if len(file_bytes) > _MAX_IMAGE_BYTES:
            raise HTTPException(413, "Image exceeds 10 MB limit")
        
        # Upload to ImgBB
        async with httpx.AsyncClient(timeout=30.0) as client:
            files = {"image": (image.filename, file_bytes, image.content_type)}
            try:
                response = await client.post(
                    f"https://api.imgbb.com/1/upload?key={IMGBB_API_KEY}",
                    files=files
                )
                if response.status_code == 200:
                    data = response.json()
                    img_path = data.get("data", {}).get("url")
                else:
                    print(f"ImgBB upload failed: {response.text}")
            except Exception as e:
                print(f"Error uploading to ImgBB: {e}")

    report = AccidentReport(
        latitude=latitude,
        longitude=longitude,
        severity=severity,
        casualties=casualties,
        description=description,
        image_path=img_path,
        status="open",
    )
    db.add(report)

    db.add(AppLog(
        event_type="ACCIDENT_REPORTED",
        latitude=latitude,
        longitude=longitude,
        log_metadata=json.dumps({"severity": severity, "casualties": casualties}),
    ))

    await db.flush()
    await db.refresh(report)

    # Convert Accident to SOS for dispatch
    from app.models.db_models import SOSAlert
    from app.routers.dispatch import trigger_dispatch
    
    alert = SOSAlert(
        latitude=latitude,
        longitude=longitude,
        severity=severity,
        message=f"ACCIDENT REPORT: {severity.upper()} severity, {casualties} casualties. {description or ''}",
        device_id="accident_report",
        status="active"
    )
    db.add(alert)
    await db.flush()
    await db.refresh(alert)
    
    # Auto-trigger dispatch
    await trigger_dispatch(alert.id, db)

    return {
        "status": "ok",
        "report_id": report.id,
        "has_image": img_path is not None,
        "message": "Accident report saved. Emergency services may be alerted.",
    }


@router.get("/reports", summary="List accident reports")
async def list_reports(
    status: Optional[str] = None,
    severity: Optional[str] = None,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
):
    # Filter BEFORE limit so we get the correct result set
    query = select(AccidentReport)
    if status:
        query = query.where(AccidentReport.status == status)
    if severity:
        query = query.where(AccidentReport.severity == severity)
    query = query.order_by(AccidentReport.reported_at.desc()).limit(limit)

    result = await db.execute(query)
    reports = result.scalars().all()
    return {
        "total": len(reports),
        "reports": [
            {
                "id": r.id,
                "lat": r.latitude,
                "lng": r.longitude,
                "severity": r.severity,
                "casualties": r.casualties,
                "status": r.status,
                "reported_at": str(r.reported_at),
            }
            for r in reports
        ],
    }


@router.get("/reports/{report_id}", summary="Get a specific accident report")
async def get_report(report_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(AccidentReport).where(AccidentReport.id == report_id))
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(404, "Report not found")
    return {
        "id": report.id,
        "latitude": report.latitude,
        "longitude": report.longitude,
        "severity": report.severity,
        "casualties": report.casualties,
        "description": report.description,
        "image_path": report.image_path,
        "status": report.status,
        "reported_at": str(report.reported_at),
    }


@router.patch("/reports/{report_id}/status", summary="Update accident report status")
async def update_report_status(report_id: int, payload: StatusUpdate, db: AsyncSession = Depends(get_db)):
    from app.models.db_models import AccidentStatusEnum
    if payload.status not in AccidentStatusEnum.__members__:
        raise HTTPException(400, f"Invalid status. Choose: {list(AccidentStatusEnum.__members__)}")
        
    result = await db.execute(select(AccidentReport).where(AccidentReport.id == report_id))
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(404, "Report not found")
        
    report.status = payload.status
    return {"status": "ok", "report_id": report.id, "new_status": report.status}
