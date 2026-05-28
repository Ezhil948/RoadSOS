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
    result = await db.execute(select(Officer).where(Officer.badge_number == payload.badge_number))
    officer = result.scalar_one_or_none()
    if not officer:
        # Auto-create officer for MVP so testing doesn't require pre-seeded DB
        officer = Officer(
            name=f"Officer {payload.badge_number}",
            badge_number=payload.badge_number,
            phone=None,
            status="offline"
        )
        db.add(officer)
        await db.flush()
        await db.refresh(officer)
    return LoginResponse(
        officer_id=officer.id,
        name=officer.name,
        badge_number=officer.badge_number,
        status=officer.status.value if hasattr(officer.status, 'value') else str(officer.status),
    )
