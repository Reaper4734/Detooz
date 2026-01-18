"""Guardian linking router - OTP-based linking between users and guardians"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from datetime import datetime, timedelta
from pydantic import BaseModel, EmailStr
import random
import string

from app.db import get_db
from app.models import User, GuardianLink
from app.routers.auth import get_current_user

router = APIRouter()


# ============ SCHEMAS ============

class GenerateOTPResponse(BaseModel):
    otp_code: str
    expires_in_minutes: int = 10
    message: str


class VerifyOTPRequest(BaseModel):
    user_email: str  # Email of the user to link to (The Protected User)
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


# ============ USER ENDPOINTS (Protected User Side) ============

@router.post("/generate-otp", response_model=GenerateOTPResponse)
async def generate_link_otp(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    User A (Protected) generates OTP.
    User A shares this with User B (Guardian).
    """

    # CONSTRAINT CHECK: Can User A be protected?
    # If User A is already a guardian for someone else, they cannot be protected?
    # "If B is guardian of A then B cannot have C... as their guardian"
    # This implies a chain: C -> B -> A.
    # If I am A (Protected), I cannot be a Guardian (B) for someone else (X).
    # Check if current_user protects anyone.
    
    protecting_others = await db.execute(
        select(GuardianLink).where(
            GuardianLink.guardian_id == current_user.id,
            GuardianLink.status == 'active'
        )
    )
    if protecting_others.scalars().first():
        raise HTTPException(
            status_code=400, 
            detail="You are currently a Guardian for someone. You cannot have a Guardian while you are protecting others."
        )
    
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
    """Get list of guardians protecting ME (current_user)"""
    
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.user_id == current_user.id,
            GuardianLink.status == "active"
        )
    )
    links = result.scalars().all()
    
    guardians = []
    for link in links:
        guardian_name = "Unknown"
        guardian_email = "Unknown"
        
        if link.guardian_id:
            g_user = await db.get(User, link.guardian_id)
            if g_user:
                guardian_name = f"{g_user.first_name} {g_user.last_name}"
                guardian_email = g_user.email
        
        guardians.append(LinkedGuardianResponse(
            guardian_id=link.guardian_id,
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
    """Revoke a guardian's access (Can be called by User or Guardian)"""
    
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.id == link_id,
            or_(GuardianLink.user_id == current_user.id, GuardianLink.guardian_id == current_user.id)
        )
    )
    link = result.scalar_one_or_none()
    
    if not link:
        raise HTTPException(status_code=404, detail="Guardian link not found")
    
    # We can either delete the row or mark as revoked.
    # Deleting is cleaner for retries.
    await db.delete(link)
    await db.commit()
    
    return {"message": "Guardian connection removed"}


# ============ GUARDIAN ENDPOINTS (Guardian Side) ============

@router.post("/verify-otp")
async def verify_otp_and_link(
    data: VerifyOTPRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)  # This is the Guardian User (B)
):
    """
    User B (Guardian) enters OTP from User A (Protected).
    Checks constraints before linking.
    """
    
    # 1. basic self check
    if current_user.email == data.user_email:
        raise HTTPException(status_code=400, detail="You cannot be your own guardian.")

    # 2. Find protected user (A)
    user_result = await db.execute(
        select(User).where(User.email == data.user_email)
    )
    protected_user = user_result.scalar_one_or_none()
    
    if not protected_user:
        raise HTTPException(status_code=404, detail="User not found")

    # 3. CONSTRAINT: Guardian (B) cannot have their own Guardians (C)
    # "If B is guardian... B cannot have C... as their guardian"
    has_guardians = await db.execute(
        select(GuardianLink).where(
            GuardianLink.user_id == current_user.id,
            GuardianLink.status == 'active'
        )
    )
    if has_guardians.scalars().first():
        raise HTTPException(
            status_code=400, 
            detail="You have guardians protecting you. You cannot be a guardian for others while protected."
        )

    # 4. CONSTRAINT: Protected User (A) cannot be a Guardian for others (X)
    # (Avoid chains/loops)
    is_protecting_others = await db.execute(
        select(GuardianLink).where(
            GuardianLink.guardian_id == protected_user.id,
            GuardianLink.status == 'active'
        )
    )
    if is_protecting_others.scalars().first():
        raise HTTPException(
            status_code=400,
            detail="The user you are trying to protect is already a guardian for someone else. Chains are not allowed."
        )

    # 5. Find pending link
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.user_id == protected_user.id,
            GuardianLink.otp_code == data.otp_code,
            GuardianLink.status == "pending"
        )
    )
    link = result.scalar_one_or_none()
    
    if not link:
        raise HTTPException(status_code=400, detail="Invalid OTP or no pending link")
    
    # 6. Check Expiry
    if link.otp_expires_at and datetime.utcnow() > link.otp_expires_at:
        raise HTTPException(status_code=400, detail="OTP has expired.")
    
    # 7. Activate Link
    link.guardian_id = current_user.id
    link.status = "active"
    link.verified_at = datetime.utcnow()
    link.otp_code = None
    link.otp_expires_at = None
    
    await db.commit()
    
    return {
        "message": f"You are now protecting {protected_user.first_name}",
        "user_name": f"{protected_user.first_name} {protected_user.last_name}",
        "user_email": protected_user.email
    }


@router.get("/my-protected-users", response_model=list[LinkedUserResponse])
async def get_protected_users(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get list of users I am protecting"""
    
    result = await db.execute(
        select(GuardianLink).where(
            GuardianLink.guardian_id == current_user.id,
            GuardianLink.status == "active"
        )
    )
    links = result.scalars().all()
    
    users = []
    for link in links:
        u_user = await db.get(User, link.user_id)
        if u_user:
            users.append(LinkedUserResponse(
                user_id=u_user.id,
                user_name=f"{u_user.first_name} {u_user.last_name}",
                user_email=u_user.email,
                status=link.status,
                linked_at=link.verified_at
            ))
    
    return users
