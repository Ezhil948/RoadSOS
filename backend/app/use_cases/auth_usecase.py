from app.infrastructure.repositories.auth_repository import AuthRepository
from app.utils.security import verify_password
from app.models.schemas import LoginResponse
from fastapi import HTTPException

class AuthUseCase:
    def __init__(self, repo: AuthRepository):
        self.repo = repo

    async def authenticate_officer(self, badge_number: str, password: str) -> LoginResponse:
        officer = await self.repo.get_officer_by_badge(badge_number)
        
        if not officer:
            raise HTTPException(status_code=401, detail="Invalid badge number or password")
            
        if not verify_password(password, officer.password_hash):
            raise HTTPException(status_code=401, detail="Invalid badge number or password")
            
        return LoginResponse(
            officer_id=officer.id,
            name=officer.name,
            badge_number=officer.badge_number,
            status=officer.status.value if hasattr(officer.status, 'value') else str(officer.status),
        )
