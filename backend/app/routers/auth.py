"""Auth router — officer login (MVP: badge-number lookup, no JWT)."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import Officer
from app.models.schemas import LoginRequest, LoginResponse

router = APIRouter()

@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    from app.utils.security import hash_password, verify_password
    
    result = await db.execute(select(Officer).where(Officer.badge_number == payload.badge_number))
    officer = result.scalar_one_or_none()
    
    if not officer:
        raise HTTPException(status_code=401, detail="Invalid badge number or password")
        
    # Verify password
    if not verify_password(payload.password, officer.password_hash):
        raise HTTPException(status_code=401, detail="Invalid badge number or password")
            
    return LoginResponse(
        officer_id=officer.id,
        name=officer.name,
        badge_number=officer.badge_number,
        status=officer.status.value if hasattr(officer.status, 'value') else str(officer.status),
    )
