from app.infrastructure.repositories.dispatch_repository import DispatchRepository
from app.utils.geo import haversine_km
import json

class DispatchUseCase:
    def __init__(self, repo: DispatchRepository):
        self.repo = repo

    async def ping_location(self, officer_id: int, lat: float, lng: float, status: str):
        officer = await self.repo.get_officer(officer_id)
        if not officer:
            return {"error": "Officer not found", "status_code": 404}
        
        await self.repo.update_officer_location_status(officer, lat, lng, status)
        return {"status": "ok"}

    async def poll_dispatch(self, officer_id: int):
        alert = await self.repo.get_active_dispatch_for_officer(officer_id)
        if not alert:
            return {"has_dispatch": False}

        officer = await self.repo.get_officer(officer_id)
        dist = haversine_km(officer.latitude, officer.longitude, alert.latitude, alert.longitude)

        return {
            "has_dispatch": True,
            "dispatch": {
                "alert_id": alert.id,
                "latitude": alert.latitude,
                "longitude": alert.longitude,
                "severity": alert.severity,
                "distance_km": round(dist, 2),
                "eta_mins": int(dist * 2),
                "message": alert.message or "Emergency SOS",
                "location_update_pending": alert.location_update_pending,
                "new_lat": alert.new_lat,
                "new_lng": alert.new_lng,
                "type": alert.alert_type,
                "requester_id": alert.requester_id,
            }
        }

    async def respond_to_dispatch(self, officer_id: int, alert_id: int, action: str):
        alert = await self.repo.get_alert_with_lock(alert_id)
        if not alert:
            return {"error": "Alert not found", "status_code": 400}

        pinged_officers = json.loads(alert.pinged_officer_ids or "[]") if isinstance(alert.pinged_officer_ids, str) else (alert.pinged_officer_ids or [])
        
        if officer_id not in pinged_officers and alert.accepted_officer_id != officer_id:
            return {"error": "Dispatch expired or not assigned to you", "status_code": 400}

        if action == "accept":
            if alert.accepted_officer_id and alert.accepted_officer_id != officer_id:
                return {"error": "Dispatch already accepted by another officer", "status_code": 400}
                
            alert.status = "active" 
            alert.accepted_officer_id = officer_id
                
            officer = await self.repo.get_officer(officer_id)
            officer.status = "busy"
            
            await self.repo.log_event("DISPATCH_ACCEPTED", {"alert_id": alert_id, "officer_id": officer_id})
            
            # Finding #12: Use await instead of asyncio.create_task for WS notifications
            from app.utils.websocket_manager import manager
            for oid in pinged_officers:
                if oid != officer_id:
                    try:
                        await manager.send_personal_message({"type": "DISPATCH_CANCELLED"}, oid)
                    except Exception as e:
                        print(f"WARNING: Failed to notify officer {oid} of dispatch taken: {e}")
                    
            return {"status": "accepted"}
            
        elif action in ("reject", "missed"):
            if officer_id in pinged_officers:
                pinged_officers.remove(officer_id)
                alert.pinged_officer_ids = list(pinged_officers)
                
            rejected_officers = alert.rejected_officer_ids or []
            if isinstance(rejected_officers, str):
                rejected_officers = json.loads(rejected_officers)
            if officer_id not in rejected_officers:
                rejected_officers.append(officer_id)
                alert.rejected_officer_ids = list(rejected_officers)
                
            await self.repo.log_event(f"DISPATCH_{action.upper()}", {"alert_id": alert_id, "officer_id": officer_id})
            
            # Trigger dispatch to find the next available officer, excluding this one
            await self.find_and_assign_officers(alert_id)
            return {"status": action}
            
        return {"error": "Invalid action", "status_code": 400}

    async def find_and_assign_officers(self, alert_id: int):
        alert = await self.repo.get_alert(alert_id)
        if not alert:
            return {"status": "error", "message": "Alert not found"}
        if not alert.latitude or not alert.longitude:
            alert.requires_manual_dispatch = True
            await self.repo.session.flush()
            return {"status": "manual_dispatch_required", "message": "Alert has no location data"}

        rejected_ids = alert.rejected_officer_ids or []
        if isinstance(rejected_ids, str):
            rejected_ids = json.loads(rejected_ids)

        top_officers_data = await self.repo.find_nearest_officers(
            alert.latitude, alert.longitude, limit=5, excluded_ids=rejected_ids
        )

        if not top_officers_data:
            alert.pinged_officer_ids = []
            return {"status": "no_officers"}

        all_officer_ids = [row.Officer.id for row in top_officers_data]
        closest_distance = top_officers_data[0].distance

        alert.pinged_officer_ids = all_officer_ids

        # Finding #12: Use await instead of asyncio.create_task for WS notifications
        from app.utils.websocket_manager import manager
        for oid in all_officer_ids:
            try:
                await manager.send_personal_message({"type": "DISPATCH_INCOMING"}, oid)
            except Exception as e:
                print(f"WARNING: Failed to notify officer {oid} of incoming dispatch: {e}")

        return {
            "status": "dispatched",
            "officer_count": len(all_officer_ids),
            "officer_ids": all_officer_ids,
            "closest_distance_km": round(closest_distance, 2) if closest_distance else 0.0,
        }

    async def request_backup(self, officer_id: int, lat: float, lng: float, message: str):
        officer = await self.repo.get_officer(officer_id)
        if not officer:
            return {"error": "Officer not found", "status_code": 404}
            
        msg = message or f"Officer {officer.badge_number} needs backup!"
        alert = await self.repo.create_backup_alert(lat, lng, msg, officer_id)
        
        await self.repo.log_event("OFFICER_BACKUP_REQUESTED", {"officer_id": officer_id, "lat": lat, "lng": lng})
        
        dispatch_res = await self.find_and_assign_officers(alert.id)
        
        return {
            "status": "ok",
            "alert_id": alert.id,
            "dispatch_status": dispatch_res
        }
