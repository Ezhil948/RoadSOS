import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.utils.database import DATABASE_URL

async def alter_db_v3():
    engine = create_async_engine(DATABASE_URL)
    async with engine.begin() as conn:
        # Add columns to sos_alerts
        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN citizen_name VARCHAR(255) NULL;"))
            print("Added citizen_name column to sos_alerts.")
        except Exception as e: print(e)
        
        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN citizen_phone VARCHAR(50) NULL;"))
            print("Added citizen_phone column to sos_alerts.")
        except Exception as e: print(e)

        # Add columns to accident_reports
        try:
            await conn.execute(text("ALTER TABLE accident_reports ADD COLUMN citizen_name VARCHAR(255) NULL;"))
            print("Added citizen_name column to accident_reports.")
        except Exception as e: print(e)
        
        try:
            await conn.execute(text("ALTER TABLE accident_reports ADD COLUMN citizen_phone VARCHAR(50) NULL;"))
            print("Added citizen_phone column to accident_reports.")
        except Exception as e: print(e)

if __name__ == "__main__":
    asyncio.run(alter_db_v3())
