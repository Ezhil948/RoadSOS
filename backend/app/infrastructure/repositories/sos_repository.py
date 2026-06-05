from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from sqlalchemy.sql import func
from app.models.db_models import SOSAlert, AppLog, Officer, DeviceTrust
from datetime import datetime, timedelta
import json

class SOSRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_recent_alert_by_device(self, device_id: str, seconds: int = 300) -> SOSAlert:
        result = await self.session.execute(
            select(SOSAlert).where(
                SOSAlert.device_id == device_id,
                SOSAlert.alerted_at >= datetime.utcnow() - timedelta(seconds=seconds)
            ).order_by(SOSAlert.alerted_at.desc())
        )
        return result.scalars().first()

    async def get_active_nearby_alerts(self, lat: float, lng: float, box_km: float = 0.5):
        import math
        bb_lat = box_km / 111.0
        bb_lng = box_km / (111.0 * math.cos(math.radians(lat)))

        query = select(SOSAlert).where(
            SOSAlert.status == "active",
            SOSAlert.latitude.between(lat - bb_lat, lat + bb_lat),
            SOSAlert.longitude.between(lng - bb_lng, lng + bb_lng)
        )
        result = await self.session.execute(query)
        return result.scalars().all()

    async def create_alert(self, lat: float, lng: float, severity: str, message: str, device_id: str, citizen_name: str = None, citizen_phone: str = None) -> SOSAlert:
        alert = SOSAlert(
            latitude=lat,
            longitude=lng,
            severity=severity,
            message=message,
            device_id=device_id,
            status="active",
            citizen_name=citizen_name,
            citizen_phone=citizen_phone
        )
        self.session.add(alert)
        await self.session.flush()
        await self.session.refresh(alert)
        return alert

    async def log_event(self, event_type: str, metadata: dict, lat: float = None, lng: float = None, device_id: str = None):
        log = AppLog(
            event_type=event_type,
            log_metadata=json.dumps(metadata)
        )
        if lat is not None: log.latitude = lat
        if lng is not None: log.longitude = lng
        if device_id is not None: log.device_id = device_id
        
        self.session.add(log)
        await self.session.flush()

    async def cancel_timeout_alerts(self, seconds: int = 300):
        cutoff_time = datetime.utcnow() - timedelta(seconds=seconds)
        
        # 1. Cancel entirely if past 5 minutes
        await self.session.execute(
            update(SOSAlert).where(
                SOSAlert.status == "active",
                SOSAlert.accepted_officer_id.is_(None),
                SOSAlert.alerted_at < cutoff_time
            ).values(
                status="cancelled",
                cancellation_reason="timeout",
                cancelled_by="system",
                resolved_at=func.now()
            )
        )
        
        # 2. Flag for manual dispatch if past 1 minute
        manual_cutoff = datetime.utcnow() - timedelta(seconds=60)
        await self.session.execute(
            update(SOSAlert).where(
                SOSAlert.status == "active",
                SOSAlert.accepted_officer_id.is_(None),
                SOSAlert.requires_manual_dispatch == False,
                SOSAlert.alerted_at < manual_cutoff
            ).values(
                requires_manual_dispatch=True
            )
        )
        
        await self.session.flush()

    async def get_alerts(self, status: str = None, limit: int = 50):
        query = select(SOSAlert)
        if status:
            query = query.where(SOSAlert.status == status)
        query = query.order_by(SOSAlert.alerted_at.desc()).limit(limit)

        result = await self.session.execute(query)
        return result.scalars().all()

    async def get_alert(self, alert_id: int) -> SOSAlert:
        result = await self.session.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
        return result.scalar_one_or_none()

    async def get_alert_with_lock(self, alert_id: int) -> SOSAlert:
        """Finding #14: SELECT FOR UPDATE to prevent race conditions between
        citizen cancel and officer acceptance."""
        result = await self.session.execute(
            select(SOSAlert).where(SOSAlert.id == alert_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def get_officer(self, officer_id: int) -> Officer:
        result = await self.session.execute(select(Officer).where(Officer.id == officer_id))
        return result.scalar_one_or_none()

    async def penalize_device_trust(self, device_id: str, penalty: int = 50):
        result = await self.session.execute(select(DeviceTrust).where(DeviceTrust.device_id == device_id))
        trust = result.scalar_one_or_none()
        if not trust:
            trust = DeviceTrust(device_id=device_id, trust_score=100)
            self.session.add(trust)
            
        trust.trust_score = max(0, trust.trust_score - penalty)
        trust.false_alarms_count += 1
        await self.session.flush()

    async def save_closure_photos(self, alert_id: int, photo_urls: list):
        alert = await self.get_alert(alert_id)
        if alert:
            alert.closure_photo_urls = photo_urls
            await self.session.commit()

    async def commit(self):
        await self.session.commit()
    
    async def flush(self):
        await self.session.flush()
