import asyncio
from sqlalchemy.ext.asyncio import AsyncSession
from app.utils.database import AsyncSessionLocal, engine, Base
from app.models.db_models import Officer
from app.utils.security import hash_password

async def seed_officers():
    print("Connecting to database to insert test officers...")
    
    # Pre-defined test credentials
    test_officers = [
        {"name": "SGT. Rajan Kumar", "badge": "4821", "password": "password123"},
        {"name": "PC Meena Iyer", "badge": "9001", "password": "secure999"},
        {"name": "INSP. Vikram Singh", "badge": "7777", "password": "admin"},
        {"name": "SGT. Priya Patel", "badge": "1234", "password": "demo"},
        {"name": "PC Rahul Sharma", "badge": "5555", "password": "roadsos"},
    ]
    
    async with AsyncSessionLocal() as db:
        for data in test_officers:
            # Hash the password
            hashed = hash_password(data["password"])
            
            # Create officer object
            officer = Officer(
                name=data["name"],
                badge_number=data["badge"],
                phone=f"+91 987654{data['badge']}",
                status="offline",
                password_hash=hashed
            )
            db.add(officer)
            print(f"Prepared officer: {data['name']} (Badge: {data['badge']})")
        
        try:
            await db.commit()
            print("Successfully inserted all 5 officers into the database!")
        except Exception as e:
            await db.rollback()
            print(f"Error inserting officers: {e}. (They might already exist!)")

if __name__ == "__main__":
    asyncio.run(seed_officers())
