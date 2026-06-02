import asyncio
from app.utils.database import AsyncSessionLocal, engine
from app.models.db_models import SOSAlert, Officer
from sqlalchemy import select, func, or_, and_
from datetime import datetime, timedelta

async def main():
    async with AsyncSessionLocal() as session:
        # Create a test officer and SOS
        officer = Officer(name="Test", badge_number="B123", latitude=10.0, longitude=10.0, status="available")
        session.add(officer)
        await session.flush()
        
        alert = SOSAlert(latitude=10.0, longitude=10.0, status="active", pinged_officer_ids=[officer.id])
        session.add(alert)
        await session.flush()
        
        officer_id = officer.id
        cutoff_time = datetime.utcnow() - timedelta(seconds=300)
        
        print("Testing json_contains with str(officer_id):", str(officer_id))
        
        query = select(SOSAlert).where(
            SOSAlert.status == "active",
            or_(
                SOSAlert.accepted_officer_id == officer_id,
                and_(
                    SOSAlert.accepted_officer_id.is_(None),
                    func.json_contains(SOSAlert.pinged_officer_ids, str(officer_id)) == 1
                )
            )
        )
        
        try:
            result = await session.execute(query)
            alerts = result.scalars().all()
            print("Found alerts:", len(alerts))
            if alerts:
                print("Alert ID:", alerts[0].id)
        except Exception as e:
            print("Query Error:", e)
            
        await session.rollback()

if __name__ == "__main__":
    asyncio.run(main())
