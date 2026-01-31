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
from app.models import User, Scan, TrustedSender, UserSettings, RiskLevel, PlatformType, GuardianLink
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


class UserProfileUpdate(BaseModel):
    """Update user profile"""
    first_name: str | None = None
    middle_name: str | None = None
    last_name: str | None = None
    phone: str | None = None


class UserProfileResponse(BaseModel):
    """User profile response"""
    id: int
    email: str
    name: str
    phone: str | None
    
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
    
    # Guardians count (Active links)
    guardians_result = await db.execute(
        select(func.count(GuardianLink.id)).where(
            GuardianLink.user_id == current_user.id,
            GuardianLink.status == 'active'
        )
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


# ============== Profile Update ==============

@router.get("/profile", response_model=UserProfileResponse)
async def get_profile(
    current_user: User = Depends(get_current_user)
):
    """Get current user profile"""
    return UserProfileResponse(
        id=current_user.id,
        email=current_user.email,
        name=current_user.name,
        phone=current_user.phone
    )


@router.put("/profile", response_model=UserProfileResponse)
async def update_profile(
    update: UserProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update user profile (name, phone)"""
    
    # Build new name from parts
    name_parts = []
    if update.first_name is not None:
        name_parts.append(update.first_name.strip())
    if update.middle_name is not None and update.middle_name.strip():
        name_parts.append(update.middle_name.strip())
    if update.last_name is not None:
        name_parts.append(update.last_name.strip())
    
    if name_parts:
        current_user.name = " ".join(name_parts)
    
    if update.phone is not None:
        current_user.phone = update.phone.strip() if update.phone else None
    
    await db.commit()
    await db.refresh(current_user)
    
    return UserProfileResponse(
        id=current_user.id,
        email=current_user.email,
        name=current_user.name,
        phone=current_user.phone
    )


# ============== FCM Token ==============

class FCMTokenRequest(BaseModel):
    """FCM token registration request"""
    fcm_token: str


@router.post("/fcm-token")
async def register_fcm_token(
    request: FCMTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Register Firebase Cloud Messaging token for push notifications.
    Called by Flutter app on startup and token refresh.
    """
    current_user.fcm_token = request.fcm_token
    await db.commit()
    
    return {"message": "FCM token registered", "success": True}


@router.delete("/fcm-token")
async def remove_fcm_token(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Remove FCM token (called on logout)"""
    current_user.fcm_token = None
    await db.commit()
    
    return {"message": "FCM token removed", "success": True}


# ============== Security & Privacy ==============

class ChangePasswordRequest(BaseModel):
    """Change password request"""
    current_password: str
    new_password: str


class DeleteAccountRequest(BaseModel):
    """Delete account request"""
    password: str


@router.post("/change-password")
async def change_password(
    request: ChangePasswordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Change user password.
    Requires current password for verification.
    """
    from app.routers.auth import verify_password, get_password_hash
    
    # Verify current password
    if not verify_password(request.current_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    
    # Validate new password
    if len(request.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    
    if request.current_password == request.new_password:
        raise HTTPException(status_code=400, detail="New password must be different")
    
    # Update password
    current_user.password_hash = get_password_hash(request.new_password)
    await db.commit()
    
    return {"message": "Password changed successfully", "success": True}


@router.get("/export-data")
async def export_user_data(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Export all user data as formatted TXT.
    GDPR-compliant data export.
    """
    from fastapi.responses import PlainTextResponse
    
    # Get user scans
    scans_result = await db.execute(
        select(Scan)
        .where(Scan.user_id == current_user.id)
        .order_by(Scan.created_at.desc())
        .limit(500)
    )
    scans = scans_result.scalars().all()
    
    # Get trusted senders
    trusted_result = await db.execute(
        select(TrustedSender).where(TrustedSender.user_id == current_user.id)
    )
    trusted = trusted_result.scalars().all()
    
    # Get settings
    settings_result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    settings = settings_result.scalar_one_or_none()
    
    # Build TXT content
    lines = [
        "=" * 50,
        "  DETOOZ - YOUR DATA EXPORT",
        f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "=" * 50,
        "",
        "PROFILE",
        "-" * 30,
        f"Name: {current_user.first_name} {current_user.middle_name or ''} {current_user.last_name}".strip(),
        f"Email: {current_user.email}",
        f"Phone: {current_user.phone or 'Not set'}",
        f"Joined: {current_user.created_at.strftime('%Y-%m-%d')}",
        "",
        f"SCAN HISTORY ({len(scans)} scans)",
        "-" * 30,
    ]
    
    for i, scan in enumerate(scans, 1):
        lines.append(f"{i}. [{scan.risk_level.value}] {scan.created_at.strftime('%Y-%m-%d %H:%M')}")
        lines.append(f"   Sender: {scan.sender or 'Unknown'}")
        lines.append(f"   Message: {(scan.message_preview or scan.message or '')[:100]}...")
        if scan.scam_type:
            lines.append(f"   Scam Type: {scan.scam_type}")
        lines.append("")
    
    lines.extend([
        f"TRUSTED SENDERS ({len(trusted)})",
        "-" * 30,
    ])
    
    for ts in trusted:
        lines.append(f"- {ts.sender} ({ts.name or 'No name'})")
    
    lines.extend([
        "",
        "SETTINGS",
        "-" * 30,
    ])
    
    if settings:
        lines.append(f"Language: {settings.language}")
        lines.append(f"Auto-block high risk: {settings.auto_block_high_risk}")
        lines.append(f"Guardian alert threshold: {settings.alert_guardians_threshold}")
        lines.append(f"Receive tips: {settings.receive_tips}")
    else:
        lines.append("Default settings")
    
    lines.extend([
        "",
        "=" * 50,
        "  End of Export",
        "=" * 50,
    ])
    
    return PlainTextResponse("\n".join(lines))


@router.delete("/delete-account")
async def delete_account(
    request: DeleteAccountRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Permanently delete user account and all associated data.
    Requires password confirmation.
    """
    from app.routers.auth import verify_password
    
    # Verify password
    if not verify_password(request.password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect password")
    
    # Delete user (cascades to related data)
    await db.delete(current_user)
    await db.commit()
    
    return {"message": "Account deleted successfully", "success": True}

