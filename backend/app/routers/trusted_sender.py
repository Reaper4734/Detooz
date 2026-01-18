"""
Trusted Sender Management API
Mark senders as trusted to bypass scam alerts
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from pydantic import BaseModel
from app.db import get_db
from app.models import User, TrustedSender
from app.routers.auth import get_current_user

router = APIRouter()


# ============== Schemas ==============

class TrustedSenderCreate(BaseModel):
    """Request to mark a sender as trusted"""
    sender: str
    name: str | None = None
    reason: str | None = None


class TrustedSenderResponse(BaseModel):
    """Response for trusted sender"""
    id: int
    sender: str
    name: str | None
    reason: str | None
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============== Endpoints ==============

@router.get("/list", response_model=list[TrustedSenderResponse])
async def list_trusted_senders(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all trusted senders for current user"""
    result = await db.execute(
        select(TrustedSender).where(TrustedSender.user_id == current_user.id)
    )
    return result.scalars().all()


@router.post("/add", response_model=TrustedSenderResponse)
async def add_trusted_sender(
    data: TrustedSenderCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark a sender as trusted"""
    
    # Check if already trusted
    existing = await db.execute(
        select(TrustedSender).where(
            TrustedSender.user_id == current_user.id,
            TrustedSender.sender == data.sender
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Sender already trusted")
    
    trusted = TrustedSender(
        user_id=current_user.id,
        sender=data.sender,
        name=data.name,
        reason=data.reason
    )
    
    db.add(trusted)
    await db.commit()
    await db.refresh(trusted)
    
    return trusted


@router.delete("/{sender}")
async def remove_trusted_sender(
    sender: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Remove a sender from trusted list"""
    
    result = await db.execute(
        select(TrustedSender).where(
            TrustedSender.user_id == current_user.id,
            TrustedSender.sender == sender
        )
    )
    trusted = result.scalar_one_or_none()
    
    if not trusted:
        raise HTTPException(status_code=404, detail="Sender not in trusted list")
    
    await db.delete(trusted)
    await db.commit()
    
    return {"message": f"Sender {sender} removed from trusted list"}


@router.get("/check/{sender}")
async def check_if_trusted(
    sender: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Check if a sender is trusted"""
    
    result = await db.execute(
        select(TrustedSender).where(
            TrustedSender.user_id == current_user.id,
            TrustedSender.sender == sender
        )
    )
    trusted = result.scalar_one_or_none()
    
    return {
        "sender": sender,
        "is_trusted": trusted is not None,
        "name": trusted.name if trusted else None
    }
