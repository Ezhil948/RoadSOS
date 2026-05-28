"""Feedback router — service ratings and reviews."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func as sql_func
from app.utils.database import get_db
from app.models.db_models import ServiceFeedback, CachedService
from pydantic import BaseModel
from typing import Optional

router = APIRouter()


class FeedbackIn(BaseModel):
    service_id: int
    rating: int       # 1-5
    comment: Optional[str] = None
    device_id: Optional[str] = None


@router.post("/submit", summary="Submit feedback for a service")
async def submit_feedback(payload: FeedbackIn, db: AsyncSession = Depends(get_db)):
    if not (1 <= payload.rating <= 5):
        raise HTTPException(400, "Rating must be 1-5")

    # Verify service exists
    result = await db.execute(select(CachedService).where(CachedService.id == payload.service_id))
    if not result.scalar_one_or_none():
        raise HTTPException(404, f"Service {payload.service_id} not found")

    fb = ServiceFeedback(
        service_id=payload.service_id,
        rating=payload.rating,
        comment=payload.comment,
        device_id=payload.device_id,
    )
    db.add(fb)
    await db.flush()
    await db.refresh(fb)
    return {"status": "ok", "feedback_id": fb.id}


@router.get("/service/{service_id}", summary="Get feedback for a service")
async def get_service_feedback(service_id: int, db: AsyncSession = Depends(get_db)):
    # Compute average in SQL — O(1) memory instead of loading all rows into Python
    stats = await db.execute(
        select(
            sql_func.avg(ServiceFeedback.rating).label("avg_rating"),
            sql_func.count().label("total"),
        ).where(ServiceFeedback.service_id == service_id)
    )
    row = stats.one()
    avg_rating = round(float(row.avg_rating or 0), 1)
    total = row.total

    # Fetch recent feedbacks (paginated, not unbounded)
    result = await db.execute(
        select(ServiceFeedback)
        .where(ServiceFeedback.service_id == service_id)
        .order_by(ServiceFeedback.submitted_at.desc())
        .limit(50)
    )
    feedbacks = result.scalars().all()

    return {
        "service_id": service_id,
        "average_rating": avg_rating,
        "total_reviews": total,
        "feedbacks": [
            {"rating": f.rating, "comment": f.comment, "at": str(f.submitted_at)}
            for f in feedbacks
        ],
    }
