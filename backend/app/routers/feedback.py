"""
Feedback Collection API
Collect user feedback on scan results for model improvement
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from pydantic import BaseModel
from app.db import get_db
from app.models import User, Scan, Feedback
from app.routers.auth import get_current_user

router = APIRouter()


# ============== Schemas ==============

class FeedbackCreate(BaseModel):
    """Submit feedback on a scan result"""
    user_verdict: str  # "safe", "scam", "unsure"
    comment: str | None = None


class FeedbackResponse(BaseModel):
    """Feedback response"""
    id: int
    scan_id: int
    user_verdict: str
    original_verdict: str | None
    comment: str | None
    created_at: datetime
    
    class Config:
        from_attributes = True


class FeedbackStats(BaseModel):
    """Aggregated feedback statistics"""
    total_feedback: int
    marked_as_safe: int  # Marked safe but was flagged as scam
    marked_as_scam: int  # Marked scam but was flagged safe
    agreement_rate: float  # How often users agree with AI


# ============== Endpoints ==============

@router.post("/scan/{scan_id}", response_model=FeedbackResponse)
async def submit_feedback(
    scan_id: int,
    data: FeedbackCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Submit feedback on a scan result"""
    
    # Validate verdict
    if data.user_verdict not in ["safe", "scam", "unsure"]:
        raise HTTPException(status_code=400, detail="Verdict must be 'safe', 'scam', or 'unsure'")
    
    # Get the scan
    scan_result = await db.execute(
        select(Scan).where(
            Scan.id == scan_id,
            Scan.user_id == current_user.id
        )
    )
    scan = scan_result.scalar_one_or_none()
    
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    
    # Check for existing feedback
    existing = await db.execute(
        select(Feedback).where(
            Feedback.scan_id == scan_id,
            Feedback.user_id == current_user.id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Feedback already submitted for this scan")
    
    # Map AI risk level to verdict
    original_verdict = "safe" if scan.risk_level.value == "LOW" else "scam"
    
    feedback = Feedback(
        user_id=current_user.id,
        scan_id=scan_id,
        user_verdict=data.user_verdict,
        original_verdict=original_verdict,
        comment=data.comment
    )
    
    db.add(feedback)
    await db.commit()
    await db.refresh(feedback)
    
    return feedback


@router.get("/my-feedback", response_model=list[FeedbackResponse])
async def get_my_feedback(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all feedback submitted by current user"""
    
    result = await db.execute(
        select(Feedback)
        .where(Feedback.user_id == current_user.id)
        .order_by(Feedback.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/stats", response_model=FeedbackStats)
async def get_feedback_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get feedback statistics for current user"""
    
    result = await db.execute(
        select(Feedback).where(Feedback.user_id == current_user.id)
    )
    feedbacks = result.scalars().all()
    
    total = len(feedbacks)
    
    if total == 0:
        return FeedbackStats(
            total_feedback=0,
            marked_as_safe=0,
            marked_as_scam=0,
            agreement_rate=1.0
        )
    
    marked_safe = sum(1 for f in feedbacks if f.user_verdict == "safe" and f.original_verdict == "scam")
    marked_scam = sum(1 for f in feedbacks if f.user_verdict == "scam" and f.original_verdict == "safe")
    agreements = sum(1 for f in feedbacks if f.user_verdict == f.original_verdict or f.user_verdict == "unsure")
    
    return FeedbackStats(
        total_feedback=total,
        marked_as_safe=marked_safe,
        marked_as_scam=marked_scam,
        agreement_rate=round(agreements / total, 2)
    )


@router.delete("/scan/{scan_id}")
async def delete_feedback(
    scan_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete feedback for a scan"""
    
    result = await db.execute(
        select(Feedback).where(
            Feedback.scan_id == scan_id,
            Feedback.user_id == current_user.id
        )
    )
    feedback = result.scalar_one_or_none()
    
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback not found")
    
    await db.delete(feedback)
    await db.commit()
    
    return {"message": "Feedback deleted"}
