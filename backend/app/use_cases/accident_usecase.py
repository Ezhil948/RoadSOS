from app.infrastructure.repositories.accident_repository import AccidentRepository
from app.presentation.routers.dispatch import trigger_dispatch_internal
from app.models.db_models import AccidentStatusEnum
import httpx
import json
import os

IMGBB_API_KEY = os.getenv("IMGBB_API_KEY")

class AccidentUseCase:
    def __init__(self, repo: AccidentRepository):
        self.repo = repo

    async def submit_report(self, background_tasks, latitude: float, longitude: float, severity: str, casualties: int, description: str, file_bytes: bytes, filename: str, content_type: str):
        report = await self.repo.create_report(latitude, longitude, severity, casualties, description)
        
        metadata = json.dumps({"severity": severity, "casualties": casualties})
        await self.repo.log_event("ACCIDENT_REPORTED", latitude, longitude, metadata)
        
        await self.repo.flush()
        await self.repo.refresh(report)

        message = f"ACCIDENT REPORT: {severity.upper()} severity, {casualties} casualties. {description or ''}"
        alert = await self.repo.create_sos_alert(latitude, longitude, severity, message)
        
        await self.repo.flush()
        await self.repo.refresh(alert)
        
        await trigger_dispatch_internal(alert.id, self.repo.session)
        
        if file_bytes and filename:
            from app.utils.database import AsyncSessionLocal
            background_tasks.add_task(self.upload_accident_image_task, report.id, file_bytes, filename, content_type, AsyncSessionLocal())

        return {
            "status": "ok",
            "report_id": report.id,
            "has_image": bool(filename and file_bytes),
            "message": "Accident report saved. Emergency services may be alerted. Image uploading in background." if (filename and file_bytes) else "Accident report saved. Emergency services may be alerted.",
        }

    @staticmethod
    async def upload_accident_image_task(report_id: int, image_bytes: bytes, filename: str, content_type: str, session):
        try:
            img_path = None
            async with httpx.AsyncClient(timeout=30.0) as client:
                files = {"image": (filename, image_bytes, content_type)}
                try:
                    response = await client.post(
                        f"https://api.imgbb.com/1/upload?key={IMGBB_API_KEY}",
                        files=files
                    )
                    if response.status_code == 200:
                        data = response.json()
                        img_path = data.get("data", {}).get("url")
                except Exception as e:
                    print(f"Error uploading to ImgBB: {e}")
                    
            if img_path:
                repo = AccidentRepository(session)
                await repo.update_image_path(report_id, img_path)
        finally:
            await session.close()

    async def list_reports(self, status: str, severity: str, limit: int):
        reports = await self.repo.get_reports(status, severity, limit)
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

    async def get_report(self, report_id: int):
        report = await self.repo.get_report_by_id(report_id)
        if not report:
            return None
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

    async def update_report_status(self, report_id: int, status: str):
        if status not in AccidentStatusEnum.__members__:
            return {"error": "invalid_status", "members": list(AccidentStatusEnum.__members__)}
            
        report = await self.repo.get_report_by_id(report_id)
        if not report:
            return {"error": "not_found"}
            
        report.status = status
        await self.repo.flush()
        return {"status": "ok", "report_id": report.id, "new_status": report.status}
