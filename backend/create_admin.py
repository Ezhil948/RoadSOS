import asyncio
from app.utils.database import get_db
from app.models.db_models import Officer

async def create_admin():
    async for db in get_db():
        new_admin = Officer(
            badge_number='admin',
            name='Admin',
            password_hash='3c8129a8a23bca7f08aad481dc98baa5$f342d87e3b980e365dfbd774c4aa3651583d4a9683105a56d308248131b432e3'
        )
        db.add(new_admin)
        await db.commit()
        print('Admin created!')

asyncio.run(create_admin())
