from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
from pydantic import BaseModel
from app.db import get_db
from app.models import User, Scan, Guardian, RiskLevel, PlatformType
from app.routers.auth import get_current_user
from app.services.scam_detector import ScamDetector
from app.services.guardian_alert_service import send_guardian_alerts

router = APIRouter()
detector = ScamDetector()


# ============== SMS-Specific Schemas ==============

class SMSMessage(BaseModel):
    """Single SMS message for analysis"""
    sender: str
    message: str
    timestamp: datetime | None = None


class SMSBatchRequest(BaseModel):
    """Batch of SMS messages (for initial sync)"""
    messages: list[SMSMessage]


class SMSAnalysisResult(BaseModel):
    """Result of SMS analysis"""
    sender: str
    message_preview: str
    risk_level: RiskLevel
    reason: str
    scam_type: str | None
    confidence: float
    is_blocked: bool
    guardian_alerted: bool
    scan_id: int


class BlockedSender(BaseModel):
    """Blocked sender info"""
    sender: str
    blocked_at: datetime
    reason: str


class SMSStats(BaseModel):
    """SMS scanning statistics"""
    total_scans: int
    high_risk: int
    medium_risk: int
    low_risk: int
    blocked_senders: int
    last_scan: datetime | None


# ============== SMS Endpoints ==============

@router.post("/analyze", response_model=SMSAnalysisResult)
async def analyze_sms(
    sms: SMSMessage,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Analyze a single SMS message for scam indicators.
    This is the main endpoint called when a new SMS arrives.
    """
    
    # Check if sender is already blocked
    blocked_result = await db.execute(
        select(Scan).where(
            Scan.user_id == current_user.id,
            Scan.sender == sms.sender,
            Scan.is_blocked == True
        ).limit(1)
    )
    is_blocked = blocked_result.scalar_one_or_none() is not None
    
    # If blocked, return HIGH risk immediately without AI call
    if is_blocked:
        # Still save the scan for records
        scan = Scan(
            user_id=current_user.id,
            sender=sms.sender,
            message=sms.message,
            message_preview=sms.message[:200] if len(sms.message) > 200 else sms.message,
            platform=PlatformType.SMS,
            risk_level=RiskLevel.HIGH,
            risk_reason="Sender is on block list",
            scam_type="Blocked Sender",
            confidence=1.0,
            is_blocked=True,
            guardian_alerted=False
        )
        db.add(scan)
        await db.commit()
        await db.refresh(scan)
        
        return SMSAnalysisResult(
            sender=sms.sender,
            message_preview=scan.message_preview,
            risk_level=RiskLevel.HIGH,
            reason="Sender is on block list",
            scam_type="Blocked Sender",
            confidence=1.0,
            is_blocked=True,
            guardian_alerted=False,
            scan_id=scan.id
        )
    
    # Run scam detection
    result = await detector.analyze(sms.message, sms.sender)
    
    # Create scan record
    scan = Scan(
        user_id=current_user.id,
        sender=sms.sender,
        message=sms.message,
        message_preview=sms.message[:200] if len(sms.message) > 200 else sms.message,
        platform=PlatformType.SMS,
        risk_level=RiskLevel(result["risk_level"]),
        risk_reason=result["reason"],
        scam_type=result.get("scam_type"),
        confidence=result["confidence"],
        is_blocked=False,
        guardian_alerted=False
    )
    
    db.add(scan)
    await db.commit()
    await db.refresh(scan)
    
    # Send alert to guardians if HIGH risk (in background)
    if result["risk_level"] == "HIGH":
        background_tasks.add_task(
            send_guardian_alerts,
            db, current_user, scan, result
        )
    
    return SMSAnalysisResult(
        sender=sms.sender,
        message_preview=scan.message_preview,
        risk_level=RiskLevel(result["risk_level"]),
        reason=result["reason"],
        scam_type=result.get("scam_type"),
        confidence=result["confidence"],
        is_blocked=False,
        guardian_alerted=scan.guardian_alerted,
        scan_id=scan.id
    )


@router.post("/analyze-batch", response_model=list[SMSAnalysisResult])
async def analyze_sms_batch(
    batch: SMSBatchRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Analyze multiple SMS messages at once.
    Useful for initial app setup to scan existing messages.
    Limited to 50 messages per request.
    """
    
    if len(batch.messages) > 50:
        raise HTTPException(
            status_code=400,
            detail="Maximum 50 messages per batch"
        )
    
    results = []
    
    for sms in batch.messages:
        # Run detection (simplified, no guardian alerts for batch)
        result = await detector.analyze(sms.message, sms.sender)
        
        scan = Scan(
            user_id=current_user.id,
            sender=sms.sender,
            message=sms.message,
            message_preview=sms.message[:200] if len(sms.message) > 200 else sms.message,
            platform=PlatformType.SMS,
            risk_level=RiskLevel(result["risk_level"]),
            risk_reason=result["reason"],
            scam_type=result.get("scam_type"),
            confidence=result["confidence"],
            is_blocked=False,
            guardian_alerted=False
        )
        
        db.add(scan)
        await db.commit()
        await db.refresh(scan)
        
        results.append(SMSAnalysisResult(
            sender=sms.sender,
            message_preview=scan.message_preview,
            risk_level=RiskLevel(result["risk_level"]),
            reason=result["reason"],
            scam_type=result.get("scam_type"),
            confidence=result["confidence"],
            is_blocked=False,
            guardian_alerted=False,
            scan_id=scan.id
        ))
    
    return results


@router.post("/block/{sender}")
async def block_sender(
    sender: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Block a sender from future messages"""
    
    # Mark all scans from this sender as blocked
    result = await db.execute(
        select(Scan).where(
            Scan.user_id == current_user.id,
            Scan.sender == sender
        )
    )
    scans = result.scalars().all()
    
    for scan in scans:
        scan.is_blocked = True
    
    # If no scans exist, create a placeholder blocked entry
    if not scans:
        scan = Scan(
            user_id=current_user.id,
            sender=sender,
            message="[Blocked sender]",
            message_preview="[Blocked sender]",
            platform=PlatformType.SMS,
            risk_level=RiskLevel.HIGH,
            risk_reason="Manually blocked by user",
            scam_type="Blocked Sender",
            confidence=1.0,
            is_blocked=True,
            guardian_alerted=False
        )
        db.add(scan)
    
    await db.commit()
    
    return {"message": f"Sender {sender} has been blocked"}


@router.delete("/block/{sender}")
async def unblock_sender(
    sender: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Unblock a previously blocked sender"""
    
    result = await db.execute(
        select(Scan).where(
            Scan.user_id == current_user.id,
            Scan.sender == sender,
            Scan.is_blocked == True
        )
    )
    scans = result.scalars().all()
    
    if not scans:
        raise HTTPException(status_code=404, detail="Sender not in block list")
    
    for scan in scans:
        scan.is_blocked = False
    
    await db.commit()
    
    return {"message": f"Sender {sender} has been unblocked"}


@router.get("/blocked", response_model=list[BlockedSender])
async def get_blocked_senders(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get list of all blocked senders"""
    
    # Get distinct blocked senders
    result = await db.execute(
        select(Scan.sender, Scan.created_at, Scan.risk_reason)
        .where(
            Scan.user_id == current_user.id,
            Scan.is_blocked == True
        )
        .distinct(Scan.sender)
        .order_by(Scan.sender, Scan.created_at.desc())
    )
    
    blocked = []
    seen_senders = set()
    
    for row in result:
        if row.sender not in seen_senders:
            blocked.append(BlockedSender(
                sender=row.sender,
                blocked_at=row.created_at,
                reason=row.risk_reason or "Blocked by user"
            ))
            seen_senders.add(row.sender)
    
    return blocked


@router.get("/stats", response_model=SMSStats)
async def get_sms_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get SMS scanning statistics for current user"""
    
    # Total scans
    total_result = await db.execute(
        select(func.count(Scan.id)).where(
            Scan.user_id == current_user.id,
            Scan.platform == PlatformType.SMS
        )
    )
    total = total_result.scalar() or 0
    
    # High risk count
    high_result = await db.execute(
        select(func.count(Scan.id)).where(
            Scan.user_id == current_user.id,
            Scan.platform == PlatformType.SMS,
            Scan.risk_level == RiskLevel.HIGH
        )
    )
    high = high_result.scalar() or 0
    
    # Medium risk count
    medium_result = await db.execute(
        select(func.count(Scan.id)).where(
            Scan.user_id == current_user.id,
            Scan.platform == PlatformType.SMS,
            Scan.risk_level == RiskLevel.MEDIUM
        )
    )
    medium = medium_result.scalar() or 0
    
    # Low risk count
    low = total - high - medium
    
    # Blocked senders count
    blocked_result = await db.execute(
        select(func.count(func.distinct(Scan.sender))).where(
            Scan.user_id == current_user.id,
            Scan.is_blocked == True
        )
    )
    blocked = blocked_result.scalar() or 0
    
    # Last scan
    last_result = await db.execute(
        select(Scan.created_at).where(
            Scan.user_id == current_user.id,
            Scan.platform == PlatformType.SMS
        ).order_by(Scan.created_at.desc()).limit(1)
    )
    last_scan = last_result.scalar()
    
    return SMSStats(
        total_scans=total,
        high_risk=high,
        medium_risk=medium,
        low_risk=low,
        blocked_senders=blocked,
        last_scan=last_scan
    )


@router.get("/recent", response_model=list[SMSAnalysisResult])
async def get_recent_sms(
    limit: int = 20,
    high_risk_only: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get recent SMS scans"""
    
    query = select(Scan).where(
        Scan.user_id == current_user.id,
        Scan.platform == PlatformType.SMS
    )
    
    if high_risk_only:
        query = query.where(Scan.risk_level == RiskLevel.HIGH)
    
    query = query.order_by(Scan.created_at.desc()).limit(limit)
    
    result = await db.execute(query)
    scans = result.scalars().all()
    
    return [
        SMSAnalysisResult(
            sender=scan.sender,
            message_preview=scan.message_preview,
            risk_level=scan.risk_level,
            reason=scan.risk_reason,
            scam_type=scan.scam_type,
            confidence=scan.confidence,
            is_blocked=scan.is_blocked,
            guardian_alerted=scan.guardian_alerted,
            scan_id=scan.id
        )
        for scan in scans
    ]


# ============== Helper Functions ==============

async def send_guardian_alerts(db: AsyncSession, user: User, scan: Scan, result: dict):
    """Background task to send guardian alerts"""
    try:
        guardians_result = await db.execute(
            select(Guardian).where(
                Guardian.user_id == user.id,
                Guardian.is_verified == True
            )
        )
        guardians = guardians_result.scalars().all()
        
        for guardian in guardians:
            if guardian.callmebot_apikey or guardian.telegram_chat_id:
                success = await alert_service.send_scam_alert(
                    phone=guardian.phone,
                    apikey=guardian.callmebot_apikey,
                    user_name=user.name,
                    sender=scan.sender,
                    risk_level=result["risk_level"],
                    reason=result["reason"],
                    telegram_chat_id=guardian.telegram_chat_id
                )
                if success:
                    guardian.last_alert_sent = datetime.utcnow()
                    scan.guardian_alerted = True
        
        await db.commit()
    except Exception as e:
        print(f"Error sending guardian alerts: {e}")
