"""Guardian linking router - OTP-based linking between users and guardians"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta
from pydantic import BaseModel, EmailStr
import random
import string

from app.db import get_db
from app.models import User, GuardianAccount, GuardianLink
from app.routers.auth import get_current_user

router = APIRouter()


# ============ SCHEMAS ============

class GenerateOTPResponse(BaseModel):
    otp_code: str
    expires_in_minutes: int = 10
    message: str


class VerifyOTPRequest(BaseModel):
    user_email: str  # Email of the user to link to
    otp_code: str


class LinkedUserResponse(BaseModel):
    user_id: int
    user_name: str
    user_email: str
    status: str
    linked_at: datetime | None

    class Config:
        from_attributes = True


class LinkedGuardianResponse(BaseModel):
    guardian_id: int | None
    guardian_name: str | None
    guardian_email: str | None
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


# ============ HELPERS ============

def generate_otp() -> str:
    """Generate 6-digit numeric OTP"""
    return ''.join(random.choices(string.digits, k=6))


# ============ USER ENDPOINTS (Victim side) ============

@router.post("/generate-otp", response_model=GenerateOTPResponse)
async def generate_link_otp(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Generate OTP for guardian linking.
    User shares this OTP with their guardian verbally.
    """
    
    otp_code = generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=10)
    
    # Check for existing pending link
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.user_id == current_user.id,
            GuardianLink.status == "pending"
        )
    )
    existing_link = result.scalar_one_or_none()
    
    if existing_link:
        # Update existing pending link with new OTP
        existing_link.otp_code = otp_code
        existing_link.otp_expires_at = expires_at
    else:
        # Create new pending link
        new_link = GuardianLink(
            user_id=current_user.id,
            otp_code=otp_code,
            otp_expires_at=expires_at,
            status="pending"
        )
        db.add(new_link)
    
    await db.commit()
    
    return GenerateOTPResponse(
        otp_code=otp_code,
        expires_in_minutes=10,
        message=f"Share this OTP with your guardian. Valid for 10 minutes."
    )


@router.get("/my-guardians", response_model=list[LinkedGuardianResponse])
async def get_my_guardians(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get list of verified guardians linked to current user (active only)"""
    
    # Only return active (verified) guardians - not pending ones
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.user_id == current_user.id,
            GuardianLink.status == "active"  # Only active, not pending
        )
    )
    links = result.scalars().all()
    
    guardians = []
    for link in links:
        guardian_name = None
        guardian_email = None
        
        if link.guardian_account_id:
            guardian_result = await db.execute(
                select(GuardianAccount).where(GuardianAccount.id == link.guardian_account_id)
            )
            guardian = guardian_result.scalar_one_or_none()
            if guardian:
                guardian_name = guardian.name
                guardian_email = guardian.email
        
        guardians.append(LinkedGuardianResponse(
            guardian_id=link.guardian_account_id,
            guardian_name=guardian_name,
            guardian_email=guardian_email,
            status=link.status,
            created_at=link.created_at
        ))
    
    return guardians


@router.delete("/revoke/{link_id}")
async def revoke_guardian_link(
    link_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Revoke a guardian's access"""
    
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.id == link_id,
            GuardianLink.user_id == current_user.id
        )
    )
    link = result.scalar_one_or_none()
    
    if not link:
        raise HTTPException(status_code=404, detail="Guardian link not found")
    
    link.status = "revoked"
    await db.commit()
    
    return {"message": "Guardian access revoked"}


# ============ GUARDIAN ENDPOINTS ============

@router.post("/verify-otp")
async def verify_otp_and_link(
    data: VerifyOTPRequest,
    guardian_id: int,  # This will come from guardian auth token
    db: AsyncSession = Depends(get_db)
):
    """
    Guardian verifies OTP to link with user.
    Called from guardian's app after they enter the OTP.
    """
    
    # Find user by email
    user_result = await db.execute(
        select(User).where(User.email == data.user_email)
    )
    user = user_result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Find pending link with matching OTP
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.user_id == user.id,
            GuardianLink.otp_code == data.otp_code,
            GuardianLink.status == "pending"
        )
    )
    link = result.scalar_one_or_none()
    
    if not link:
        raise HTTPException(status_code=400, detail="Invalid OTP or no pending link")
    
    # Check OTP expiry
    if link.otp_expires_at and datetime.utcnow() > link.otp_expires_at:
        raise HTTPException(status_code=400, detail="OTP has expired. Please generate a new one.")
    
    # Verify and activate link
    link.guardian_account_id = guardian_id
    link.status = "active"
    link.verified_at = datetime.utcnow()
    link.otp_code = None  # Clear OTP after use
    link.otp_expires_at = None
    
    await db.commit()
    
    return {
        "message": "Successfully linked to user",
        "user_name": user.name,
        "user_email": user.email
    }


@router.get("/my-protected-users", response_model=list[LinkedUserResponse])
async def get_protected_users(
    guardian_id: int,  # This will come from guardian auth token
    db: AsyncSession = Depends(get_db)
):
    """Get list of users this guardian is protecting"""
    
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.guardian_account_id == guardian_id,
            GuardianLink.status == "active"
        )
    )
    links = result.scalars().all()
    
    users = []
    for link in links:
        user_result = await db.execute(
            select(User).where(User.id == link.user_id)
        )
        user = user_result.scalar_one_or_none()
        if user:
            users.append(LinkedUserResponse(
                user_id=user.id,
                user_name=user.name,
                user_email=user.email,
                status=link.status,
                linked_at=link.verified_at
            ))
    
    return users
