import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.utils.database import DATABASE_URL

async def alter_db_v4():
    engine = create_async_engine(DATABASE_URL)
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN requires_manual_dispatch BOOLEAN DEFAULT FALSE;"))
            print("Added requires_manual_dispatch to sos_alerts.")
        except Exception as e: print(e)
        
        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN category VARCHAR(100) NULL;"))
            print("Added category to sos_alerts.")
        except Exception as e: print(e)

if __name__ == "__main__":
    asyncio.run(alter_db_v4())
