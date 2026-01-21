"""Guardian linking router - OTP-based linking between users and guardians"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from datetime import datetime, timedelta
from pydantic import BaseModel, EmailStr
import random
import string
import json
from typing import Dict

from app.db import get_db
from app.models import User, GuardianLink
from app.routers.auth import get_current_user
from app.core.redis_client import redis_client

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
    Stored in Redis (10 min TTL).
    """
    
    # CONSTRAINT CHECK: Can User A be protected?
    # If User A is already a guardian for someone else, they cannot be protected?
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
    
    # Store in Redis
    otp_data = {
        "user_id": current_user.id,
        "email": current_user.email,
        "expires_at_iso": expires_at.isoformat()
    }
    
    # Use redis_client
    # Key: otp:{otp_code} -> ensures uniqueness of code. 
    # Production note: Better to key by user_id to prevent spam, but code lookup is faster for verification.
    success = redis_client.setex(f"otp:{otp_code}", 600, json.dumps(otp_data))
    
    if not success:
         # Fallback error if Redis is down (since strict consistency needed)
         raise HTTPException(status_code=503, detail="Service unavailable (Cache Error)")
    
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
        
    # 2. Check Redis Cache for OTP
    cached_json = redis_client.get(f"otp:{data.otp_code}")
    
    if not cached_json:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    
    try:
        cached_data = json.loads(cached_json)
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Cache data corruption")
        
    # Check email match
    if cached_data["email"] != data.user_email:
        raise HTTPException(status_code=400, detail="OTP matches a different user")

    # 3. Find protected user (A)
    # Use ID from cache to be safe
    protected_user_id = cached_data["user_id"]
    
    # 4. CONSTRAINT: Guardian (B) cannot have their own Guardians (C)
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

    # 5. CONSTRAINT: Protected User (A) cannot be a Guardian for others (X)
    is_protecting_others = await db.execute(
        select(GuardianLink).where(
            GuardianLink.guardian_id == protected_user_id,
            GuardianLink.status == 'active'
        )
    )
    if is_protecting_others.scalars().first():
        raise HTTPException(
            status_code=400,
            detail="The user you are trying to protect is already a guardian for someone else. Chains are not allowed."
        )

    # 6. Check if already linked
    existing = await db.execute(
        select(GuardianLink).where(
            GuardianLink.user_id == protected_user_id,
            GuardianLink.guardian_id == current_user.id
        )
    )
    if existing.scalar_one_or_none():
         # Already active, just return success
         redis_client.delete(f"otp:{data.otp_code}")
         return {"message": "You are already protecting this user"}

    # 7. Create ACTIVE Link
    new_link = GuardianLink(
        user_id=protected_user_id,
        guardian_id=current_user.id,
        status="active",
        verified_at=datetime.utcnow()
    )
    
    db.add(new_link)
    await db.commit()
    
    # 8. Remove from cache (Atomic enough for this use case)
    redis_client.delete(f"otp:{data.otp_code}")
    
    return {
        "message": f"You are now protecting {data.user_email}",
        "user_email": data.user_email
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
