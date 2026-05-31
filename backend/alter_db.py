import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.utils.database import DATABASE_URL

async def alter_db():
    engine = create_async_engine(DATABASE_URL)
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN reporters JSON;"))
            print("Added reporters column.")
        except Exception as e: print(e)
        
        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN location_update_pending BOOLEAN DEFAULT FALSE;"))
            print("Added location_update_pending column.")
        except Exception as e: print(e)

        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN new_lat FLOAT NULL;"))
            print("Added new_lat column.")
        except Exception as e: print(e)

        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN new_lng FLOAT NULL;"))
            print("Added new_lng column.")
        except Exception as e: print(e)

        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN closure_notes TEXT NULL;"))
            print("Added closure_notes column.")
        except Exception as e: print(e)

        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN closure_photo_urls JSON;"))
            print("Added closure_photo_urls column.")
        except Exception as e: print(e)

if __name__ == "__main__":
    asyncio.run(alter_db())
