import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.utils.database import DATABASE_URL

async def alter_db_v2():
    engine = create_async_engine(DATABASE_URL)
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN alert_type VARCHAR(50) DEFAULT 'citizen_sos';"))
            print("Added alert_type column.")
        except Exception as e: print(e)
        
        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN cancellation_reason VARCHAR(100) NULL;"))
            print("Added cancellation_reason column.")
        except Exception as e: print(e)

        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN cancellation_details TEXT NULL;"))
            print("Added cancellation_details column.")
        except Exception as e: print(e)

        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN cancelled_by VARCHAR(50) NULL;"))
            print("Added cancelled_by column.")
        except Exception as e: print(e)

        try:
            await conn.execute(text("ALTER TABLE sos_alerts ADD COLUMN requester_id INTEGER NULL;"))
            print("Added requester_id column.")
        except Exception as e: print(e)
        
        # Note: We won't strictly alter the Enum `AlertStatusEnum` directly on the column because MySQL enums are annoying,
        # but SQLAlchemy string/varchar or updated enum will map correctly if the column is loose. 
        # Actually, in MySQL if `status` is ENUM('active','resolved','false_alarm'), adding 'cancelled_by_police' requires modifying the enum.
        # Let's try to modify the Enum to include 'cancelled', 'cancelled_by_police', 'cancelled_by_citizen'
        try:
            await conn.execute(text("ALTER TABLE sos_alerts MODIFY COLUMN status ENUM('active','resolved','false_alarm','cancelled','cancelled_by_police','cancelled_by_citizen') DEFAULT 'active';"))
            print("Modified status ENUM.")
        except Exception as e: print(e)

if __name__ == "__main__":
    asyncio.run(alter_db_v2())
