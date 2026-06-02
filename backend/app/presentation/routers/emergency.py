"""Emergency numbers router — per-country emergency number lookup."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, case
from app.utils.database import get_db
from app.models.db_models import EmergencyNumber
from pydantic import BaseModel
from typing import Optional

router = APIRouter()


class EmergencyNumberOut(BaseModel):
    country_code: str
    country_name: Optional[str]
    police: Optional[str]
    ambulance: Optional[str]
    fire: Optional[str]
    national_emergency: Optional[str]


@router.get("/numbers", response_model=list[EmergencyNumberOut], summary="Get all emergency numbers")
async def get_all_numbers(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(EmergencyNumber).order_by(EmergencyNumber.country_code))
    return result.scalars().all()


@router.get("/numbers/{country_code}", response_model=EmergencyNumberOut, summary="Get numbers for a country")
async def get_country_numbers(country_code: str, db: AsyncSession = Depends(get_db)):
    # Single query with fallback to DEFAULT — avoids two round-trips
    code_upper = country_code.upper()
    result = await db.execute(
        select(EmergencyNumber)
        .where(or_(
            EmergencyNumber.country_code == code_upper,
            EmergencyNumber.country_code == "DEFAULT",
        ))
        .order_by(
            case((EmergencyNumber.country_code == code_upper, 0), else_=1)
        )
        .limit(1)
    )
    row = result.scalar_one_or_none()
    if not row:
        raise HTTPException(404, f"No emergency numbers for {country_code}")
    return row
