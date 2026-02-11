from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text, distinct
from pydantic import BaseModel
from datetime import datetime
from typing import List, Any
import logging

from app.db import get_db
from app.models import User, GuardianAlert, Scan, GuardianLink
from app.routers.auth import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)

# ============ ADMIN AUTH ============

# Admin emails allowlist — add your real admin email(s) here
# In a future iteration, move this to a DB role or environment variable
ADMIN_EMAILS = [
    "detooz4734@gmail.com",
]


async def require_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    """
    Verify the authenticated user is an admin.
    Requires valid JWT token AND email in the admin allowlist.
    """
    if current_user.email not in ADMIN_EMAILS:
        logger.warning(f"Non-admin access attempt by user {current_user.id}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user


# ============ SCHEMAS ============

class DashboardStats(BaseModel):
    total_users: int
    total_guardians: int
    total_alerts: int
    total_scams_detected: int
    recent_scam_types: List[str]

class AdminUserView(BaseModel):
    id: int
    name: str
    email: str
    phone: str | None
    created_at: datetime
    
    class Config:
        from_attributes = True

# Guardian view is same as User view now, but filtered by role
class AdminGuardianView(BaseModel):
    id: int
    name: str
    email: str
    phone: str | None
    created_at: datetime
    
    class Config:
        from_attributes = True

class AdminAlertView(BaseModel):
    id: int
    user_name: str | None
    guardian_name: str | None
    risk_level: str
    message_preview: str | None
    created_at: datetime
    seen: bool

# ============ ENDPOINTS (all require admin auth) ============

@router.get("/stats", response_model=DashboardStats)
async def get_admin_stats(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Get overview statistics for the dashboard"""
    
    # Count Users
    users_count = await db.scalar(select(func.count(User.id)))
    
    # Count Guardians (Distinct users who are in the guardian_id column of active links)
    guardians_count = await db.scalar(
        select(func.count(distinct(GuardianLink.guardian_id)))
        .where(GuardianLink.status == 'active')
    )
    
    # Count Alerts
    alerts_count = await db.scalar(select(func.count(GuardianAlert.id)))
    
    # Count High Risk Scans (Scams)
    scams_count = await db.scalar(select(func.count(Scan.id)).where(Scan.risk_level == "HIGH"))
    
    # Recent scam types
    recent_scams = await db.execute(
        select(Scan.scam_type)
        .where(Scan.risk_level == "HIGH")
        .order_by(Scan.created_at.desc())
        .limit(5)
    )
    scam_types = [r for r in recent_scams.scalars().all() if r]
    
    return DashboardStats(
        total_users=users_count or 0,
        total_guardians=guardians_count or 0,
        total_alerts=alerts_count or 0,
        total_scams_detected=scams_count or 0,
        recent_scam_types=list(set(scam_types)) # Unique list
    )

@router.get("/users", response_model=List[AdminUserView])
async def get_all_users(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """List last 50 users"""
    result = await db.execute(select(User).order_by(User.created_at.desc()).limit(50))
    users = result.scalars().all()
    return [
        AdminUserView(
            id=u.id, 
            name=f"{u.first_name} {u.last_name}", 
            email=u.email, 
            phone=u.phone, 
            created_at=u.created_at
        ) 
        for u in users
    ]

@router.get("/guardians", response_model=List[AdminGuardianView])
async def get_active_guardians(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """List last 50 active guardians"""
    subquery = select(distinct(GuardianLink.guardian_id)).where(GuardianLink.status == 'active')
    
    result = await db.execute(
        select(User).where(User.id.in_(subquery)).order_by(User.created_at.desc()).limit(50)
    )
    guardians = result.scalars().all()
    
    return [
        AdminGuardianView(
            id=u.id, 
            name=f"{u.first_name} {u.last_name}", 
            email=u.email, 
            phone=u.phone, 
            created_at=u.created_at
        ) 
        for u in guardians
    ]

@router.get("/alerts", response_model=List[AdminAlertView])
async def get_all_alerts(
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """List last 50 alerts"""
    result = await db.execute(
        select(GuardianAlert).order_by(GuardianAlert.created_at.desc()).limit(50)
    )
    alerts = result.scalars().all()
    
    view_models = []
    for alert in alerts:
        u = await db.get(User, alert.user_id)
        g = await db.get(User, alert.guardian_id)
        
        view_models.append(AdminAlertView(
            id=alert.id,
            user_name=f"{u.first_name} {u.last_name}" if u else "Unknown",
            guardian_name=f"{g.first_name} {g.last_name}" if g else "Unknown",
            risk_level="HIGH",
            message_preview="View details",
            created_at=alert.created_at,
            seen=alert.seen_at is not None
        ))
    return view_models


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Delete a user and their data (Manual Cascade)"""
    try:
        user = await db.get(User, user_id)
        if not user:
            raise HTTPException(404, "User not found")
            
        # Manually delete related records to avoid SQLite FK issues
        await db.execute(text("DELETE FROM guardian_alerts WHERE user_id = :uid OR guardian_id = :uid"), {"uid": user_id})
        await db.execute(text("DELETE FROM guardian_links WHERE user_id = :uid OR guardian_id = :uid"), {"uid": user_id})
        await db.execute(text("DELETE FROM feedback WHERE user_id = :uid"), {"uid": user_id})
        await db.execute(text("DELETE FROM scans WHERE user_id = :uid"), {"uid": user_id})
        await db.execute(text("DELETE FROM trusted_senders WHERE user_id = :uid"), {"uid": user_id})
        await db.execute(text("DELETE FROM user_settings WHERE user_id = :uid"), {"uid": user_id})

        await db.delete(user)
        await db.commit()
        logger.info(f"Admin {admin.email} deleted user {user_id}")
        return {"message": "User deleted"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"User deletion failed for user_id={user_id}")
        raise HTTPException(status_code=500, detail="User deletion failed")

@router.put("/users/{user_id}")
async def update_user(
    user_id: int,
    updates: dict,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Update user details (Name, Phone only — allowlisted fields)"""
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    
    # Only allow specific fields to be updated (prevent password_hash injection)
    ALLOWED_FIELDS = {"first_name", "last_name", "phone"}
    for key in updates:
        if key not in ALLOWED_FIELDS:
            raise HTTPException(400, f"Field '{key}' cannot be updated via admin")
    
    if "first_name" in updates:
        user.first_name = updates["first_name"]
    if "last_name" in updates:
        user.last_name = updates["last_name"]
    if "phone" in updates:
        user.phone = updates["phone"]
        
    await db.commit()
    logger.info(f"Admin {admin.email} updated user {user_id}")
    return {"message": "User updated"}

@router.delete("/guardians/{guardian_id}")
async def delete_guardian(
    guardian_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Delete a guardian account"""
    return await delete_user(guardian_id, db, admin)

@router.delete("/alerts/{alert_id}")
async def delete_alert(
    alert_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Delete an alert"""
    alert = await db.get(GuardianAlert, alert_id)
    if not alert:
        raise HTTPException(404, "Alert not found")
    await db.delete(alert)
    await db.commit()
    logger.info(f"Admin {admin.email} deleted alert {alert_id}")
    return {"message": "Alert deleted"}
