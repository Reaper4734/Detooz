"""
User Management API
User statistics, settings and profile
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime
from pydantic import BaseModel
from app.db import get_db
from app.models import User, Scan, Guardian, TrustedSender, UserSettings, RiskLevel, PlatformType
from app.routers.auth import get_current_user

router = APIRouter()


# ============== Schemas ==============

class UserStats(BaseModel):
    """User statistics response"""
    total_scans: int
    high_risk_blocked: int
    medium_risk_detected: int
    low_risk_safe: int
    guardians_count: int
    trusted_senders_count: int
    blocked_senders_count: int
    protected_since: datetime | None
    last_scan_at: datetime | None
    protection_score: int  # 0-100 based on activity


class UserSettingsUpdate(BaseModel):
    """Update user settings"""
    language: str | None = None
    auto_block_high_risk: bool | None = None
    alert_guardians_threshold: str | None = None
    receive_tips: bool | None = None


class UserSettingsResponse(BaseModel):
    """User settings response"""
    language: str
    auto_block_high_risk: bool
    alert_guardians_threshold: str
    receive_tips: bool
    
    class Config:
        from_attributes = True


# ============== Endpoints ==============

@router.get("/stats", response_model=UserStats)
async def get_user_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get comprehensive user statistics"""
    
    # Total scans
    total_result = await db.execute(
        select(func.count(Scan.id)).where(Scan.user_id == current_user.id)
    )
    total_scans = total_result.scalar() or 0
    
    # High risk count
    high_result = await db.execute(
        select(func.count(Scan.id)).where(
            Scan.user_id == current_user.id,
            Scan.risk_level == RiskLevel.HIGH
        )
    )
    high_risk = high_result.scalar() or 0
    
    # Medium risk count
    medium_result = await db.execute(
        select(func.count(Scan.id)).where(
            Scan.user_id == current_user.id,
            Scan.risk_level == RiskLevel.MEDIUM
        )
    )
    medium_risk = medium_result.scalar() or 0
    
    # Low risk (safe) count
    low_risk = total_scans - high_risk - medium_risk
    
    # Guardians count
    guardians_result = await db.execute(
        select(func.count(Guardian.id)).where(Guardian.user_id == current_user.id)
    )
    guardians_count = guardians_result.scalar() or 0
    
    # Trusted senders count
    trusted_result = await db.execute(
        select(func.count(TrustedSender.id)).where(TrustedSender.user_id == current_user.id)
    )
    trusted_count = trusted_result.scalar() or 0
    
    # Blocked senders count (unique)
    blocked_result = await db.execute(
        select(func.count(func.distinct(Scan.sender))).where(
            Scan.user_id == current_user.id,
            Scan.is_blocked == True
        )
    )
    blocked_count = blocked_result.scalar() or 0
    
    # Last scan
    last_scan_result = await db.execute(
        select(Scan.created_at).where(
            Scan.user_id == current_user.id
        ).order_by(Scan.created_at.desc()).limit(1)
    )
    last_scan_at = last_scan_result.scalar()
    
    # Calculate protection score (0-100)
    # Based on: having guardians, regular scans, blocking threats
    score = 0
    if guardians_count > 0:
        score += 30
    if total_scans > 10:
        score += 20
    elif total_scans > 0:
        score += 10
    if high_risk > 0:  # Successfully detected threats
        score += 30
    if blocked_count > 0:  # User is actively blocking
        score += 20
    
    return UserStats(
        total_scans=total_scans,
        high_risk_blocked=high_risk,
        medium_risk_detected=medium_risk,
        low_risk_safe=low_risk,
        guardians_count=guardians_count,
        trusted_senders_count=trusted_count,
        blocked_senders_count=blocked_count,
        protected_since=current_user.created_at,
        last_scan_at=last_scan_at,
        protection_score=min(score, 100)
    )


@router.get("/settings", response_model=UserSettingsResponse)
async def get_user_settings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get user settings"""
    
    result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    settings = result.scalar_one_or_none()
    
    # Create default settings if not exists
    if not settings:
        settings = UserSettings(user_id=current_user.id)
        db.add(settings)
        await db.commit()
        await db.refresh(settings)
    
    return settings


@router.put("/settings", response_model=UserSettingsResponse)
async def update_user_settings(
    update: UserSettingsUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update user settings"""
    
    result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    settings = result.scalar_one_or_none()
    
    # Create if not exists
    if not settings:
        settings = UserSettings(user_id=current_user.id)
        db.add(settings)
    
    # Update fields if provided
    if update.language is not None:
        if update.language not in ["en", "hi", "ta", "te", "mr", "bn"]:
            raise HTTPException(status_code=400, detail="Unsupported language")
        settings.language = update.language
    
    if update.auto_block_high_risk is not None:
        settings.auto_block_high_risk = update.auto_block_high_risk
    
    if update.alert_guardians_threshold is not None:
        if update.alert_guardians_threshold not in ["HIGH", "MEDIUM", "ALL"]:
            raise HTTPException(status_code=400, detail="Invalid threshold")
        settings.alert_guardians_threshold = update.alert_guardians_threshold
    
    if update.receive_tips is not None:
        settings.receive_tips = update.receive_tips
    
    await db.commit()
    await db.refresh(settings)
    
    return settings


@router.put("/language/{lang}")
async def set_language(
    lang: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Quick language toggle endpoint"""
    
    if lang not in ["en", "hi"]:
        raise HTTPException(status_code=400, detail="Language must be 'en' or 'hi'")
    
    result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    settings = result.scalar_one_or_none()
    
    if not settings:
        settings = UserSettings(user_id=current_user.id, language=lang)
        db.add(settings)
    else:
        settings.language = lang
    
    await db.commit()
    
    return {"message": f"Language set to {lang}", "language": lang}
