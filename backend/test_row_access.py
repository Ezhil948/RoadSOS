import asyncio
from app.utils.database import AsyncSessionLocal
from app.models.db_models import Officer
from app.infrastructure.repositories.dispatch_repository import DispatchRepository

async def test_find():
    async with AsyncSessionLocal() as session:
        # Create an available officer
        officer = Officer(name="Test", badge_number="T123", latitude=10.0, longitude=10.0, status="available")
        session.add(officer)
        await session.flush()

        repo = DispatchRepository(session)
        result = await repo.find_nearest_officers(10.0, 10.0)
        print("Result:", result)
        if result:
            row = result[0]
            print("Row:", row)
            try:
                print("Officer ID using row.Officer.id:", row.Officer.id)
            except Exception as e:
                print("Error accessing row.Officer:", e)
                try:
                    print("Officer ID using row[0].id:", row[0].id)
                except Exception as e2:
                    print("Error accessing row[0]:", e2)
        await session.rollback()

if __name__ == "__main__":
    asyncio.run(test_find())
