from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from app.db import get_db
from app.models import User, Scan, Guardian, RiskLevel
from app.routers.auth import get_current_user
from app.schemas import ScanRequest, ScanResponse, ScanDetail
from app.services.scam_detector import ScamDetector
from app.services.alert_service import AlertService

router = APIRouter()
detector = ScamDetector()
alert_service = AlertService()


@router.post("/analyze", response_model=ScanResponse)
async def analyze_message(
    request: ScanRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Analyze a message for scam indicators"""
    
    # Run scam detection
    result = await detector.analyze(request.message, request.sender)
    
    # Create scan record
    scan = Scan(
        user_id=current_user.id,
        sender=request.sender,
        message=request.message,
        message_preview=request.message[:200] if len(request.message) > 200 else request.message,
        platform=request.platform,
        risk_level=RiskLevel(result["risk_level"]),
        risk_reason=result["reason"],
        scam_type=result.get("scam_type"),
        confidence=result["confidence"],
        guardian_alerted=False
    )
    
    db.add(scan)
    await db.commit()
    await db.refresh(scan)
    
    # Send alert to guardians if HIGH risk
    if result["risk_level"] == "HIGH":
        guardians_result = await db.execute(
            select(Guardian).where(
                Guardian.user_id == current_user.id,
                Guardian.is_verified == True
            )
        )
        guardians = guardians_result.scalars().all()
        
        for guardian in guardians:
            if guardian.callmebot_apikey:
                success = await alert_service.send_scam_alert(
                    phone=guardian.phone,
                    apikey=guardian.callmebot_apikey,
                    user_name=current_user.name,
                    sender=request.sender,
                    risk_level=result["risk_level"],
                    reason=result["reason"]
                )
                if success:
                    guardian.last_alert_sent = datetime.utcnow()
                    scan.guardian_alerted = True
        
        await db.commit()
        await db.refresh(scan)
    
    return scan


@router.get("/history", response_model=list[ScanResponse])
async def get_history(
    limit: int = 50,
    risk_level: RiskLevel | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get scan history for current user"""
    
    query = select(Scan).where(Scan.user_id == current_user.id)
    
    if risk_level:
        query = query.where(Scan.risk_level == risk_level)
    
    query = query.order_by(Scan.created_at.desc()).limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{scan_id}", response_model=ScanDetail)
async def get_scan(
    scan_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific scan by ID"""
    
    result = await db.execute(
        select(Scan).where(Scan.id == scan_id, Scan.user_id == current_user.id)
    )
    scan = result.scalar_one_or_none()
    
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    
    return scan


@router.delete("/{scan_id}")
async def delete_scan(
    scan_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a scan"""
    
    result = await db.execute(
        select(Scan).where(Scan.id == scan_id, Scan.user_id == current_user.id)
    )
    scan = result.scalar_one_or_none()
    
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    
    await db.delete(scan)
    await db.commit()
    
    return {"message": "Scan deleted"}


@router.post("/{scan_id}/block")
async def block_sender(
    scan_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Mark a sender as blocked"""
    
    result = await db.execute(
        select(Scan).where(Scan.id == scan_id, Scan.user_id == current_user.id)
    )
    scan = result.scalar_one_or_none()
    
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    
    scan.is_blocked = True
    await db.commit()
    
    return {"message": f"Sender {scan.sender} blocked"}
