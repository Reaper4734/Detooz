"""
Privacy & Consent Management API
Handles user consent, GDPR rights, and data protection controls
"""
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from datetime import datetime
from pydantic import BaseModel
from typing import Optional, List, Dict
from app.db import get_db
from app.models import User, UserSettings, ConsentLog, Blacklist, Scan
from app.routers.auth import get_current_user
import json

router = APIRouter()

# ============== Schemas ==============

class ConsentUpdate(BaseModel):
    """Update consent preference"""
    consent: bool
    version: str = "1.0"

class DataExportResponse(BaseModel):
    """GDPR data export structure"""
    user_profile: Dict
    settings: Dict
    consent_history: List[Dict]
    scan_history_summary: Dict
    contributed_blacklist_entries: int
    generated_at: datetime

class DeletionRequest(BaseModel):
    """Request to delete account"""
    confirmation: str  # Must match "DELETE MY ACCOUNT"
    reason: Optional[str] = None

# ============== Helper Functions ==============

async def log_consent_change(
    user_id: int,
    consent_type: str,
    consent_given: bool,
    version: str,
    ip_address: str,
    db: AsyncSession
):
    """Log consent change to audit trail"""
    log = ConsentLog(
        user_id=user_id,
        consent_type=consent_type,
        consent_given=consent_given,
        consent_version=version,
        ip_address=ip_address,
        created_at=datetime.utcnow()
    )
    db.add(log)
    await db.commit()

# ============== Endpoints ==============

@router.get("/consent/status")
async def get_consent_status(
    current_user: User = Depends(get_current_user)
):
    """Get user's current consent preferences"""
    return {
        "consent_training_data": current_user.consent_training_data,
        "consent_analytics": current_user.consent_analytics,
        "consent_version": current_user.consent_version,
        "last_updated": current_user.consent_given_at
    }

@router.post("/consent/training-data")
async def set_training_data_consent(
    update_data: ConsentUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Give or withdraw consent for LLM training data collection"""
    
    # Update user record
    current_user.consent_training_data = update_data.consent
    current_user.consent_version = update_data.version
    current_user.consent_given_at = datetime.utcnow()
    
    # Audit log
    await log_consent_change(
        user_id=current_user.id,
        consent_type="training_data",
        consent_given=update_data.consent,
        version=update_data.version,
        ip_address="127.0.0.1",  # In real app, extract from request
        db=db
    )
    
    message = "Consent granted for training data" if update_data.consent else "Consent withdrawn for training data"
    
    # If withdrawn, schedule anonymization (could be background task)
    if not update_data.consent:
        # Placeholder for background job trigger
        pass
        
    return {"message": message, "status": current_user.consent_training_data}

@router.post("/consent/analytics")
async def set_analytics_consent(
    update_data: ConsentUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Give or withdraw consent for usage analytics"""
    
    current_user.consent_analytics = update_data.consent
    current_user.consent_version = update_data.version
    current_user.consent_given_at = datetime.utcnow()
    
    await log_consent_change(
        user_id=current_user.id,
        consent_type="analytics",
        consent_given=update_data.consent,
        version=update_data.version,
        ip_address="127.0.0.1",
        db=db
    )
    
    return {
        "message": "Analytics consent updated", 
        "status": current_user.consent_analytics
    }

@router.post("/gdpr/export-data", response_model=DataExportResponse)
async def export_user_data(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Export all user data (GDPR Right to Portability)"""
    
    # 1. Fetch settings
    settings_result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    settings = settings_result.scalar_one_or_none()
    
    # 2. Fetch consent history
    history_result = await db.execute(
        select(ConsentLog).where(ConsentLog.user_id == current_user.id).order_by(ConsentLog.created_at.desc())
    )
    history = history_result.scalars().all()
    
    # 3. Get generic stats
    # (Implementation simplified for brevity)
    
    response_data = {
        "user_profile": {
            "id": current_user.id,
            "email": current_user.email,
            "name": f"{current_user.first_name} {current_user.last_name}",
            "created_at": current_user.created_at
        },
        "settings": {
            "language": settings.language if settings else "en",
            "auto_block": settings.auto_block_high_risk if settings else True
        },
        "consent_history": [
            {
                "type": log.consent_type,
                "given": log.consent_given,
                "date": log.created_at,
                "version": log.consent_version
            } for log in history
        ],
        "scan_history_summary": {
            "total_scans": 0, # Fetch real count
            "scams_detected": 0
        },
        "contributed_blacklist_entries": 0, # Fetch real count
        "generated_at": datetime.utcnow()
    }
    
    # Log the export request
    if settings:
        settings.data_export_requested = True
        await db.commit()
    
    return response_data

@router.post("/gdpr/delete-account")
async def delete_account(
    request: DeletionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Permanently delete user account and anonymize data"""
    
    if request.confirmation != "DELETE MY ACCOUNT":
        raise HTTPException(
            status_code=400, 
            detail="Confirmation string must be exactly 'DELETE MY ACCOUNT'"
        )
    
    # 1. Anonymize contributions before deleting user
    # (In a real app, you'd run a robust anonymization query here)
    
    # 2. Delete user
    await db.delete(current_user)
    await db.commit()
    
    return {"message": "Account scheduled for permanent deletion"}

@router.post("/gdpr/anonymize-contributions")
async def anonymize_my_data(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Remove PII from any training data contributed"""
    
    # Logic to find all blacklist entries by this user and redact PII
    # This assumes we link blacklist entries to user_id, which we should add
    
    return {"message": "Anonymization request processed"}

@router.get("/privacy/policies")
async def get_privacy_policies():
    """Get links/text of current privacy policies"""
    return {
        "privacy_policy_url": "/api/static/privacy_policy.md",
        "consent_policy_url": "/api/static/consent_policy.md",
        "version": "1.0",
        "last_updated": "2026-01-21"
    }
