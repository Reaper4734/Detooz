from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from app.db import get_db
from app.models import User, Guardian
from app.routers.auth import get_current_user
from app.schemas import GuardianCreate, GuardianUpdate, GuardianResponse
from app.services.alert_service import AlertService

router = APIRouter()
alert_service = AlertService()


@router.get("/list", response_model=list[GuardianResponse])
async def list_guardians(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all guardians for current user"""
    
    result = await db.execute(
        select(Guardian).where(Guardian.user_id == current_user.id)
    )
    return result.scalars().all()


@router.post("/add", response_model=GuardianResponse)
async def add_guardian(
    guardian_data: GuardianCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Add a new guardian"""
    
    guardian = Guardian(
        user_id=current_user.id,
        name=guardian_data.name,
        phone=guardian_data.phone,
        callmebot_apikey=guardian_data.callmebot_apikey,
        is_verified=guardian_data.callmebot_apikey is not None
    )
    
    db.add(guardian)
    await db.commit()
    await db.refresh(guardian)
    
    return guardian


@router.put("/{guardian_id}", response_model=GuardianResponse)
async def update_guardian(
    guardian_id: int,
    update: GuardianUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update a guardian"""
    
    result = await db.execute(
        select(Guardian).where(
            Guardian.id == guardian_id,
            Guardian.user_id == current_user.id
        )
    )
    guardian = result.scalar_one_or_none()
    
    if not guardian:
        raise HTTPException(status_code=404, detail="Guardian not found")
    
    if update.name:
        guardian.name = update.name
    if update.phone:
        guardian.phone = update.phone
    if update.callmebot_apikey:
        guardian.callmebot_apikey = update.callmebot_apikey
        guardian.is_verified = True
    
    await db.commit()
    await db.refresh(guardian)
    
    return guardian


@router.delete("/{guardian_id}")
async def delete_guardian(
    guardian_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a guardian"""
    
    result = await db.execute(
        select(Guardian).where(
            Guardian.id == guardian_id,
            Guardian.user_id == current_user.id
        )
    )
    guardian = result.scalar_one_or_none()
    
    if not guardian:
        raise HTTPException(status_code=404, detail="Guardian not found")
    
    await db.delete(guardian)
    await db.commit()
    
    return {"message": "Guardian deleted"}


@router.post("/test-alert/{guardian_id}")
async def test_alert(
    guardian_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Send a test alert to guardian"""
    
    result = await db.execute(
        select(Guardian).where(
            Guardian.id == guardian_id,
            Guardian.user_id == current_user.id
        )
    )
    guardian = result.scalar_one_or_none()
    
    if not guardian:
        raise HTTPException(status_code=404, detail="Guardian not found")
    
    if not guardian.callmebot_apikey:
        raise HTTPException(
            status_code=400,
            detail="Guardian has no CallMeBot API key configured"
        )
    
    success = await alert_service.send_test_alert(
        phone=guardian.phone,
        apikey=guardian.callmebot_apikey,
        user_name=current_user.name
    )
    
    if success:
        guardian.last_alert_sent = datetime.utcnow()
        await db.commit()
        return {"message": "Test alert sent successfully"}
    else:
        raise HTTPException(status_code=500, detail="Failed to send test alert")
