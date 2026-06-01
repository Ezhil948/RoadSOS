from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.db_models import Officer

class AuthRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_officer_by_badge(self, badge_number: str) -> Officer | None:
        result = await self.session.execute(
            select(Officer).where(Officer.badge_number == badge_number)
        )
        return result.scalar_one_or_none()
