"""Auth router — officer login (MVP: badge-number lookup, no JWT)."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.utils.database import get_db
from app.models.schemas import LoginRequest, LoginResponse
from app.infrastructure.repositories.auth_repository import AuthRepository
from app.use_cases.auth_usecase import AuthUseCase

router = APIRouter()

@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    repo = AuthRepository(db)
    use_case = AuthUseCase(repo)
    return await use_case.authenticate_officer(payload.badge_number, payload.password)
