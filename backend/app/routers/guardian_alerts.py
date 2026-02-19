"""Guardian alerts router - polling endpoint for guardian notifications"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from sqlalchemy.orm import joinedload
from datetime import datetime
from pydantic import BaseModel

from app.db import get_db
from app.models import User, GuardianLink, GuardianAlert, Scan
from app.routers.auth import get_current_user
from app.services.guardian_alert_service import guardian_alert_service

router = APIRouter()


# ============ SCHEMAS ============

class AlertResponse(BaseModel):
    id: int
    user_id: int
    user_name: str
    user_phone: str | None
    scan_id: int
    
    # Scan details
    sender: str | None
    message_preview: str | None
    risk_level: str
    risk_reason: str | None
    scam_type: str | None
    confidence: float | None
    
    # Alert status
    status: str
    created_at: datetime
    seen_at: datetime | None

    class Config:
        from_attributes = True


class ActionRequest(BaseModel):
    action: str  # "contacted_user", "blocked_sender", "dismissed", "other"
    notes: str | None = None


class ActionResponse(BaseModel):
    message: str
    alert_id: int
    action: str


# ============ ENDPOINTS ============

class SendAlertRequest(BaseModel):
    sender: str
    scam_type: str


@router.post("/send")
async def send_guardian_alert(
    request: SendAlertRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Send alert to all linked guardians for the current user.
    Called by the Flutter client when a HIGH risk message is detected locally.
    Finds the most recent scan matching the sender and triggers FCM push.
    """
    
    # Find the most recent scan for this user matching the sender
    scan_result = await db.execute(
        select(Scan).where(
            Scan.user_id == current_user.id,
            Scan.sender == request.sender
        ).order_by(desc(Scan.created_at)).limit(1)
    )
    scan = scan_result.scalar_one_or_none()
    
    if not scan:
        # No matching scan found — create a minimal scan record for the alert
        from app.models import RiskLevel
        scan = Scan(
            user_id=current_user.id,
            sender=request.sender,
            message_preview="[Alert triggered by local AI detection]",
            risk_level=RiskLevel.HIGH,
            scam_type=request.scam_type,
            confidence=0.9,
            risk_reason="High-risk message detected by on-device AI",
            guardian_alerted=False,
        )
        db.add(scan)
        await db.flush()
    
    # Use the existing guardian alert service to create alerts + send FCM
    alerts_created = await guardian_alert_service.create_alerts_for_scan(
        db, current_user, scan
    )
    
    if alerts_created == 0:
        return {
            "message": "No active guardians found to alert",
            "alerts_sent": 0
        }
    
    return {
        "message": f"Guardian alert sent successfully",
        "alerts_sent": alerts_created,
        "scan_id": scan.id
    }

@router.get("/pending", response_model=list[AlertResponse])
async def get_pending_alerts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get pending alerts for guardian (current_user).
    """
    
    # Get pending/seen alerts
    result = await db.execute(
        select(GuardianAlert).where(
            GuardianAlert.guardian_id == current_user.id,
            GuardianAlert.status.in_(["pending", "seen"])
        ).order_by(GuardianAlert.created_at.desc())
    )
    alerts = result.scalars().all()
    
    response = []
    for alert in alerts:
        # Get user info (Protected User)
        user_result = await db.execute(
            select(User).where(User.id == alert.user_id)
        )
        user = user_result.scalar_one_or_none()
        
        # Get scan info
        scan_result = await db.execute(
            select(Scan).where(Scan.id == alert.scan_id)
        )
        scan = scan_result.scalar_one_or_none()
        
        if user and scan:
            response.append(AlertResponse(
                id=alert.id,
                user_id=user.id,
                user_name=f"{user.first_name} {user.last_name}",
                user_phone=user.phone,
                scan_id=scan.id,
                sender=scan.sender,
                message_preview=scan.message_preview,
                risk_level=scan.risk_level.value if scan.risk_level else "UNKNOWN",
                risk_reason=scan.risk_reason,
                scam_type=scan.scam_type,
                confidence=scan.confidence,
                status=alert.status,
                created_at=alert.created_at,
                seen_at=alert.seen_at
            ))
    
    return response


@router.post("/{alert_id}/seen")
async def mark_alert_seen(
    alert_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark an alert as seen (guardian opened it)"""
    
    result = await db.execute(
        select(GuardianAlert).where(
            GuardianAlert.id == alert_id,
            GuardianAlert.guardian_id == current_user.id
        )
    )
    alert = result.scalar_one_or_none()
    
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    
    if alert.status == "pending":
        alert.status = "seen"
        alert.seen_at = datetime.utcnow()
        await db.commit()
    
    return {"message": "Alert marked as seen", "alert_id": alert_id}


@router.post("/{alert_id}/action", response_model=ActionResponse)
async def take_action_on_alert(
    alert_id: int,
    action_data: ActionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Take action on an alert.
    Actions: contacted_user, blocked_sender, dismissed, other
    """
    
    result = await db.execute(
        select(GuardianAlert).where(
            GuardianAlert.id == alert_id,
            GuardianAlert.guardian_id == current_user.id
        )
    )
    alert = result.scalar_one_or_none()
    
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    
    # Update alert with action
    alert.status = "actioned"
    alert.action_taken = action_data.action
    alert.action_notes = action_data.notes
    alert.actioned_at = datetime.utcnow()
    
    if not alert.seen_at:
        alert.seen_at = datetime.utcnow()
    
    await db.commit()
    
    return ActionResponse(
        message=f"Action '{action_data.action}' recorded",
        alert_id=alert_id,
        action=action_data.action
    )


@router.get("/history", response_model=list[AlertResponse])
async def get_alert_history(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all alerts (including actioned) for history view"""
    
    result = await db.execute(
        select(GuardianAlert).where(
            GuardianAlert.guardian_id == current_user.id
        ).order_by(GuardianAlert.created_at.desc()).limit(limit)
    )
    alerts = result.scalars().all()
    
    response = []
    for alert in alerts:
        user_result = await db.execute(
            select(User).where(User.id == alert.user_id)
        )
        user = user_result.scalar_one_or_none()
        
        scan_result = await db.execute(
            select(Scan).where(Scan.id == alert.scan_id)
        )
        scan = scan_result.scalar_one_or_none()
        
        if user and scan:
            response.append(AlertResponse(
                id=alert.id,
                user_id=user.id,
                user_name=f"{user.first_name} {user.last_name}",
                user_phone=user.phone,
                scan_id=scan.id,
                sender=scan.sender,
                message_preview=scan.message_preview,
                risk_level=scan.risk_level.value if scan.risk_level else "UNKNOWN",
                risk_reason=scan.risk_reason,
                scam_type=scan.scam_type,
                confidence=scan.confidence,
                status=alert.status,
                created_at=alert.created_at,
                seen_at=alert.seen_at
            ))
    
    return response
