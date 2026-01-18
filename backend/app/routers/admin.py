from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text
from pydantic import BaseModel
from datetime import datetime
from typing import List, Any

from app.db import get_db
from app.models import User, GuardianAccount, GuardianAlert, Scan, GuardianLink

router = APIRouter()

# Simple Admin Secret (in a real app this would be a separate role)
ADMIN_SECRET = "admin123"

def verify_admin(x_admin_secret: str = "admin123"):
    if x_admin_secret != ADMIN_SECRET:
        raise HTTPException(status_code=401, detail="Invalid admin secret")
    return True

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

# ============ ENDPOINTS ============

@router.get("/stats", response_model=DashboardStats)
async def get_admin_stats(
    db: AsyncSession = Depends(get_db),
    # authorized: bool = Depends(verify_admin)  # Disabled for simple demo
):
    """Get overview statistics for the dashboard"""
    
    # Count Users
    users_count = await db.scalar(select(func.count(User.id)))
    
    # Count Guardians
    guardians_count = await db.scalar(select(func.count(GuardianAccount.id)))
    
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
async def get_all_users(db: AsyncSession = Depends(get_db)):
    """List last 50 users"""
    result = await db.execute(select(User).order_by(User.created_at.desc()).limit(50))
    return result.scalars().all()

@router.get("/guardians", response_model=List[AdminGuardianView])
async def get_all_guardians(db: AsyncSession = Depends(get_db)):
    """List last 50 guardians"""
    result = await db.execute(select(GuardianAccount).order_by(GuardianAccount.created_at.desc()).limit(50))
    return result.scalars().all()

@router.get("/alerts", response_model=List[AdminAlertView])
async def get_all_alerts(db: AsyncSession = Depends(get_db)):
    """List last 50 alerts"""
    query = (
        select(GuardianAlert, User.name, GuardianAccount.name)
        .outerjoin(User, GuardianAlert.user_id == User.id)
        .outerjoin(GuardianAccount, GuardianAlert.guardian_account_id == GuardianAccount.id)
        .order_by(GuardianAlert.created_at.desc())
        .limit(50)
    )
    result = await db.execute(query)
    
    alerts = []
    for row in result:
        alert, uname, gname = row
        alerts.append(AdminAlertView(
            id=alert.id,
            user_name=uname or "Unknown",
            guardian_name=gname or "Unknown",
            risk_level=alert.risk_level,
            message_preview=alert.message_preview,
            created_at=alert.created_at,
            seen=alert.seen_at is not None
        ))
    return alerts

    return {"message": "User deleted"}

@router.delete("/users/{user_id}")
async def delete_user(user_id: int, db: AsyncSession = Depends(get_db)):
    """Delete a user and their data (Manual Cascade)"""
    try:
        user = await db.get(User, user_id)
        if not user:
            raise HTTPException(404, "User not found")
            
        # Manually delete related records to avoid SQLite FK issues
        # 1. Delete Guardian Alerts (References Scans, so delete first)
        await db.execute(text("DELETE FROM guardian_alerts WHERE user_id = :uid"), {"uid": user_id})
        
        # 2. Delete Guardian Links
        await db.execute(text("DELETE FROM guardian_links WHERE user_id = :uid"), {"uid": user_id})

        # 3. Delete Feedback (References Scans)
        await db.execute(text("DELETE FROM feedback WHERE user_id = :uid"), {"uid": user_id})
        
        # 4. Delete Scans
        await db.execute(text("DELETE FROM scans WHERE user_id = :uid"), {"uid": user_id})
        
        # 5. Delete Legacy Guardians
        await db.execute(text("DELETE FROM guardians WHERE user_id = :uid"), {"uid": user_id})
        
        # 6. Delete Trusted Senders
        await db.execute(text("DELETE FROM trusted_senders WHERE user_id = :uid"), {"uid": user_id})
        
        # 7. Delete User Settings
        await db.execute(text("DELETE FROM user_settings WHERE user_id = :uid"), {"uid": user_id})

        # Finally delete User
        await db.delete(user)
        await db.commit()
        return {"message": "User deleted"}
    except Exception as e:
        await db.rollback()
        print(f"Delete Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/users/{user_id}")
async def update_user(user_id: int, updates: dict, db: AsyncSession = Depends(get_db)):
    """Update user details (Name, Phone)"""
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    
    if "name" in updates:
        user.name = updates["name"]
    if "phone" in updates:
        user.phone = updates["phone"]
        
    await db.commit()
    return {"message": "User updated"}

@router.delete("/guardians/{guardian_id}")
async def delete_guardian(guardian_id: int, db: AsyncSession = Depends(get_db)):
    """Delete a guardian account"""
    guardian = await db.get(GuardianAccount, guardian_id)
    if not guardian:
        raise HTTPException(404, "Guardian not found")
    await db.delete(guardian)
    await db.commit()
    return {"message": "Guardian deleted"}

@router.delete("/alerts/{alert_id}")
async def delete_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    """Delete an alert"""
    alert = await db.get(GuardianAlert, alert_id)
    if not alert:
        raise HTTPException(404, "Alert not found")
    await db.delete(alert)
    await db.commit()
    return {"message": "Alert deleted"}
