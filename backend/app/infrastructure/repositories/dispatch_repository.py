from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_, update
from sqlalchemy.sql import func
from app.models.db_models import Officer, SOSAlert, AppLog
from datetime import datetime, timedelta
import json

class DispatchRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_officer(self, officer_id: int) -> Officer:
        result = await self.session.execute(select(Officer).where(Officer.id == officer_id))
        return result.scalar_one_or_none()

    async def get_alert(self, alert_id: int) -> SOSAlert:
        result = await self.session.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
        return result.scalar_one_or_none()
        
    async def get_alert_with_lock(self, alert_id: int) -> SOSAlert:
        result = await self.session.execute(
            select(SOSAlert).where(SOSAlert.id == alert_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def update_officer_location_status(self, officer: Officer, lat: float, lng: float, status: str):
        officer.latitude = lat
        officer.longitude = lng
        officer.status = status
        officer.last_ping_at = func.now()
        await self.session.flush()

    async def get_active_dispatch_for_officer(self, officer_id: int) -> SOSAlert:
        cutoff_time = datetime.utcnow() - timedelta(seconds=300)
        result = await self.session.execute(
            select(SOSAlert).where(
                SOSAlert.status == "active",
                or_(
                    SOSAlert.accepted_officer_id == officer_id,
                    and_(
                        SOSAlert.accepted_officer_id.is_(None),
                        SOSAlert.alerted_at >= cutoff_time,
                        func.json_contains(SOSAlert.pinged_officer_ids, str(officer_id)) == 1
                    )
                )
            ).order_by(SOSAlert.alerted_at.desc())
        )
        return result.scalars().first()

    async def log_event(self, event_type: str, metadata: dict):
        self.session.add(AppLog(
            event_type=event_type,
            log_metadata=json.dumps(metadata)
        ))
        await self.session.flush()

    async def find_nearest_officers(self, alert_lat: float, alert_lng: float, limit: int = 5):
        import math
        lat_delta = 50.0 / 111.0
        lng_delta = 50.0 / (111.0 * math.cos(math.radians(alert_lat)))

        distance_expr = (
            6371.0 * func.acos(
                func.least(1.0, 
                    func.cos(func.radians(alert_lat)) *
                    func.cos(func.radians(Officer.latitude)) *
                    func.cos(func.radians(Officer.longitude) - func.radians(alert_lng)) +
                    func.sin(func.radians(alert_lat)) *
                    func.sin(func.radians(Officer.latitude))
                )
            )
        ).label("distance")

        query = select(Officer, distance_expr).where(
            Officer.status == "available",
            Officer.latitude.between(alert_lat - lat_delta, alert_lat + lat_delta),
            Officer.longitude.between(alert_lng - lng_delta, alert_lng + lng_delta)
        ).order_by("distance").limit(limit)
        
        result = await self.session.execute(query)
        return result.all() # list of (Officer, distance) tuples

    async def create_backup_alert(self, lat: float, lng: float, message: str, officer_id: int) -> SOSAlert:
        alert = SOSAlert(
            latitude=lat,
            longitude=lng,
            severity="critical",
            message=message,
            alert_type="officer_backup",
            requester_id=officer_id,
            status="active"
        )
        self.session.add(alert)
        await self.session.flush()
        await self.session.refresh(alert)
        return alert

    async def commit(self):
        await self.session.commit()
