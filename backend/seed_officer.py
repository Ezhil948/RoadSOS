import asyncio
from app.utils.database import AsyncSessionLocal
from app.models.db_models import Officer, OfficerStatusEnum

async def seed_officer():
    async with AsyncSessionLocal() as db:
        from app.utils.security import hash_password
        new_officer = Officer(
            id=1,
            name="John Doe",
            badge_number="BADGE123",
            phone="555-1234",
            status=OfficerStatusEnum.offline,
            password_hash=hash_password("password")
        )
        await db.merge(new_officer)
        await db.commit()
        print("Officer seeded successfully!")

if __name__ == "__main__":
    asyncio.run(seed_officer())
