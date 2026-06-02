from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.db_models import AccidentReport, AppLog, SOSAlert

class AccidentRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
        
    def add(self, entity):
        self.session.add(entity)

    async def flush(self):
        await self.session.flush()

    async def refresh(self, entity):
        await self.session.refresh(entity)

    async def commit(self):
        await self.session.commit()

    async def create_report(self, latitude: float, longitude: float, severity: str, casualties: int, description: str, citizen_name: str = None, citizen_phone: str = None) -> AccidentReport:
        report = AccidentReport(
            latitude=latitude,
            longitude=longitude,
            severity=severity,
            casualties=casualties,
            description=description,
            image_path=None,
            status="open",
            citizen_name=citizen_name,
            citizen_phone=citizen_phone
        )
        self.add(report)
        return report

    async def log_event(self, event_type: str, latitude: float, longitude: float, metadata: str):
        self.add(AppLog(
            event_type=event_type,
            latitude=latitude,
            longitude=longitude,
            log_metadata=metadata,
        ))

    async def create_sos_alert(self, latitude: float, longitude: float, severity: str, message: str, citizen_name: str = None, citizen_phone: str = None) -> SOSAlert:
        alert = SOSAlert(
            latitude=latitude,
            longitude=longitude,
            severity=severity,
            message=message,
            device_id="accident_report",
            status="active",
            citizen_name=citizen_name,
            citizen_phone=citizen_phone
        )
        self.add(alert)
        return alert

    async def get_reports(self, status: str | None, severity: str | None, limit: int):
        query = select(AccidentReport)
        if status:
            query = query.where(AccidentReport.status == status)
        if severity:
            query = query.where(AccidentReport.severity == severity)
        query = query.order_by(AccidentReport.reported_at.desc()).limit(limit)

        result = await self.session.execute(query)
        return result.scalars().all()

    async def get_report_by_id(self, report_id: int) -> AccidentReport | None:
        result = await self.session.execute(select(AccidentReport).where(AccidentReport.id == report_id))
        return result.scalar_one_or_none()

    async def update_image_path(self, report_id: int, img_path: str):
        report = await self.get_report_by_id(report_id)
        if report:
            report.image_path = img_path
            await self.commit()
