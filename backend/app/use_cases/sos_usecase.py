from app.infrastructure.repositories.sos_repository import SOSRepository
from app.utils.geo import haversine_km
from sqlalchemy.sql import func
from datetime import datetime, timezone, timedelta
import json

class SOSUseCase:
    def __init__(self, repo: SOSRepository, dispatch_trigger_fn=None):
        self.repo = repo
        self.dispatch_trigger = dispatch_trigger_fn

    async def send_sos_alert(self, lat: float, lng: float, severity: str, message: str, device_id: str, citizen_name: str = None, citizen_phone: str = None):
        if device_id:
            recent_alert = await self.repo.get_recent_alert_by_device(device_id)
            if recent_alert:
                if recent_alert.status in ["resolved", "cancelled", "false_alarm", "cancelled_by_police", "cancelled_by_citizen"]:
                    return {
                        "error": "Cooldown active. Please wait 5 minutes before raising another alert.",
                        "status_code": 429
                    }
                else:
                    return {
                        "status": "received", "alert_id": recent_alert.id,
                        "message": "SOS already active. Officers are being dispatched.",
                        "nearest_emergency": "112", "action": "WAIT"
                    }

        active_alerts = await self.repo.get_active_nearby_alerts(lat, lng)
        for alert in active_alerts:
            dist = haversine_km(lat, lng, alert.latitude, alert.longitude)
            if dist < 0.2:
                reporters = json.loads(alert.reporters or "[]")
                if device_id and device_id not in reporters:
                    reporters.append(device_id)
                    alert.reporters = json.dumps(reporters)
                    await self.repo.flush()
                return {
                    "status": "merged", "alert_id": alert.id,
                    "message": "Your alert was merged with an existing nearby emergency. Help is on the way.",
                    "nearest_emergency": "112", "action": "WAIT"
                }

        alert = await self.repo.create_alert(lat, lng, severity, message, device_id, citizen_name, citizen_phone)
        await self.repo.log_event("SOS_TRIGGERED", {"severity": severity}, lat, lng, device_id)
        
        if self.dispatch_trigger:
            await self.dispatch_trigger(alert.id, self.repo.session)

        return {
            "status": "received", "alert_id": alert.id,
            "message": f"SOS #{alert.id} recorded. Call 112 immediately.",
            "nearest_emergency": "112", "action": "CALL_112"
        }

    async def list_sos_alerts(self, status: str = None, limit: int = 50):
        await self.repo.cancel_timeout_alerts()
        alerts = await self.repo.get_alerts(status, limit)
        return {
            "total": len(alerts),
            "alerts": [
                {
                    "id": a.id, "lat": a.latitude, "lng": a.longitude,
                    "severity": a.severity, "status": a.status, "message": a.message,
                    "alerted_at": str(a.alerted_at) + "Z", "cancellation_reason": a.cancellation_reason,
                    "cancellation_details": a.cancellation_details, "cancelled_by": a.cancelled_by,
                    "requires_manual_dispatch": a.requires_manual_dispatch, "category": a.category,
                    "citizen_name": a.citizen_name, "citizen_phone": a.citizen_phone,
                    "accepted_officer_id": a.accepted_officer_id,
                    "closure_notes": a.closure_notes, "closure_photo_urls": a.closure_photo_urls or []
                }
                for a in alerts
            ]
        }

    async def get_alert_status(self, alert_id: int):
        alert = await self.repo.get_alert(alert_id)
        if not alert:
            return {"error": "Alert not found", "status_code": 404}
            
        response = {
            "status": alert.status, "is_dispatched": False, "officer": None,
            "cancellation_reason": alert.cancellation_reason,
            "cancellation_details": alert.cancellation_details,
            "cancelled_by": alert.cancelled_by
        }
        
        if alert.status == "active":
            if alert.accepted_officer_id:
                response["is_dispatched"] = True
                officer = await self.repo.get_officer(alert.accepted_officer_id)
                if officer and officer.latitude and officer.longitude:
                    dist = haversine_km(officer.latitude, officer.longitude, alert.latitude, alert.longitude)
                    response["officer"] = {
                        "id": officer.id, "badge": officer.badge_number,
                        "distance_km": round(dist, 2), "eta_mins": int(dist * 2)
                    }
            elif not alert.pinged_officer_ids or len(alert.pinged_officer_ids) == 0:
                if alert.alerted_at:
                    delta = (datetime.now(timezone.utc) - alert.alerted_at.replace(tzinfo=timezone.utc)).total_seconds()
                    if delta > 300:
                        alert.status = "cancelled"
                        alert.cancellation_reason = "timeout"
                        alert.cancelled_by = "citizen"
                        alert.resolved_at = func.now()
                        await self.repo.flush()
                        response.update({"status": "cancelled", "cancellation_reason": "timeout", "cancelled_by": "citizen"})
                    elif int(delta) % 10 < 5 and self.dispatch_trigger:
                        await self.dispatch_trigger(alert.id, self.repo.session)
        return response

    async def resolve_alert(self, alert_id: int, notes: str):
        alert = await self.repo.get_alert(alert_id)
        if not alert: return {"error": "Alert not found", "status_code": 404}
        alert.status = "resolved"
        alert.resolved_at = func.now()
        await self.repo.log_event("SOS_RESOLVED", {"alert_id": alert_id, "officer_notes": notes})
        return {"status": "ok", "alert_id": alert_id, "message": "Alert resolved"}

    async def mark_false_alarm(self, alert_id: int, notes: str):
        alert = await self.repo.get_alert(alert_id)
        if not alert: return {"error": "Alert not found", "status_code": 404}
        alert.status = "false_alarm"
        alert.resolved_at = func.now()
        await self.repo.log_event("SOS_FALSE_ALARM", {"alert_id": alert_id, "officer_notes": notes})
        if alert.device_id: await self.repo.penalize_device_trust(alert.device_id)
        return {"status": "ok", "message": "Marked as false alarm. Device trust penalized."}

    async def cancel_sos_alert(self, alert_id: int, reason: str):
        alert = await self.repo.get_alert(alert_id)
        if not alert: return {"error": "Alert not found", "status_code": 404}
        if alert.status not in ["active", "cancelled", "cancelled_by_citizen"]:
            return {"error": f"Alert {alert_id} is already {alert.status}", "status_code": 400}
            
        if reason == "false_alarm_grace_period":
            alert.status = "false_alarm"
            alert.cancellation_reason = "citizen_grace_period"
            alert.cancelled_by = "citizen"
            alert.resolved_at = func.now()
            await self.repo.log_event("SOS_CANCELLED_FALSE_ALARM", {"alert_id": alert_id, "reason": reason})
            
            if alert.accepted_officer_id:
                from app.utils.websocket_manager import manager
                import asyncio
                asyncio.create_task(manager.send_personal_message({"type": "ALERT_CANCELLED_FALSE_ALARM"}, alert.accepted_officer_id))
        else:
            alert.status = "cancelled_by_citizen"
            alert.cancellation_reason = reason or "user_cancelled"
            alert.cancelled_by = "citizen"
            alert.resolved_at = func.now()
            await self.repo.log_event("SOS_CANCELLED_BY_CITIZEN", {"alert_id": alert_id, "reason": alert.cancellation_reason})
            
            if alert.accepted_officer_id:
                from app.utils.websocket_manager import manager
                import asyncio
                asyncio.create_task(manager.send_personal_message({"type": "DISPATCH_CANCELLED"}, alert.accepted_officer_id))

        await self.repo.flush()
        return {"status": "ok", "alert_id": alert_id, "message": "SOS cancelled."}

    async def police_cancel_alert(self, alert_id: int, reason: str, details: str):
        alert = await self.repo.get_alert(alert_id)
        if not alert: return {"error": "Alert not found", "status_code": 404}
        alert.status = "cancelled_by_police"
        alert.cancellation_reason = reason
        alert.cancellation_details = details
        alert.cancelled_by = "police"
        alert.resolved_at = func.now()
        await self.repo.log_event("SOS_CANCELLED_BY_POLICE", {"alert_id": alert_id, "reason": reason})
        return {"status": "ok", "alert_id": alert_id, "message": "Alert cancelled by police."}

    async def suggest_location_update(self, alert_id: int, new_lat: float, new_lng: float, device_id: str):
        alert = await self.repo.get_alert(alert_id)
        if not alert: return {"error": "Alert not found", "status_code": 404}
        if alert.device_id and device_id != alert.device_id: return {"error": "Unauthorized", "status_code": 403}
        if haversine_km(alert.latitude, alert.longitude, new_lat, new_lng) <= 0.2:
            return {"error": "no_significant_change", "status_code": 400}
        
        alert.location_update_pending = True
        alert.new_lat, alert.new_lng = new_lat, new_lng
        await self.repo.flush()
        return {"status": "pending_officer_approval"}

    async def confirm_location_update(self, alert_id: int):
        alert = await self.repo.get_alert(alert_id)
        if not alert or not alert.location_update_pending: return {"error": "Update not found", "status_code": 404}
        alert.latitude, alert.longitude = alert.new_lat, alert.new_lng
        alert.location_update_pending = False
        alert.new_lat = alert.new_lng = None
        await self.repo.flush()
        return {"status": "ok"}

    async def dismiss_location_update(self, alert_id: int):
        alert = await self.repo.get_alert(alert_id)
        if not alert or not alert.location_update_pending: return {"error": "Update not found", "status_code": 404}
        alert.location_update_pending = False
        alert.new_lat = alert.new_lng = None
        await self.repo.flush()
        return {"status": "ok"}

    async def patch_alert_location(self, alert_id: int, lat: float, lng: float):
        alert = await self.repo.get_alert(alert_id)
        if not alert: return {"error": "Alert not found", "status_code": 404}
        alert.latitude, alert.longitude, alert.status = lat, lng, "active"
        await self.repo.flush()
        if self.dispatch_trigger: await self.dispatch_trigger(alert.id, self.repo.session)
        return {"status": "ok", "message": "Location updated and re-dispatched"}

    async def close_incident(self, alert_id: int, notes: str, photos: list, category: str, background_tasks):
        alert = await self.repo.get_alert(alert_id)
        if not alert: return {"error": "Alert not found", "status_code": 404}
        alert.status = "resolved"
        alert.resolved_at = func.now()
        if notes: alert.closure_notes = notes
        if category: alert.category = category
        
        if photos:
            from app.utils.database import AsyncSessionLocal
            from app.infrastructure.services.storage_service import StorageService
            storage_service = StorageService()
            background_tasks.add_task(storage_service.upload_photos_task, alert_id, photos, AsyncSessionLocal())
            
        await self.repo.flush()
        await self.repo.log_event("INCIDENT_CLOSED", {"alert_id": alert_id, "photos": len(photos) if photos else 0})
        return {"status": "ok", "message": "Incident closed. Photos uploading in background."}
