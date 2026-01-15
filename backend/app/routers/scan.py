from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import datetime
from enum import Enum
from app.routers.auth import get_current_user
from app.services.scam_detector import ScamDetector

router = APIRouter()
detector = ScamDetector()


class PlatformType(str, Enum):
    SMS = "SMS"
    WHATSAPP = "WHATSAPP"
    TELEGRAM = "TELEGRAM"


class RiskLevel(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class ScanRequest(BaseModel):
    message: str
    sender: str
    platform: PlatformType = PlatformType.SMS


class ScanResponse(BaseModel):
    id: int
    risk_level: RiskLevel
    reason: str
    scam_type: str | None
    confidence: float
    sender: str
    platform: PlatformType
    message_preview: str
    created_at: datetime


# In-memory scan store (replace with database)
scans_db = {}
scan_id_counter = 1


@router.post("/analyze", response_model=ScanResponse)
async def analyze_message(
    request: ScanRequest,
    current_user: dict = Depends(get_current_user)
):
    """Analyze a message for scam indicators"""
    global scan_id_counter
    
    # Run scam detection
    result = await detector.analyze(request.message, request.sender)
    
    # Create scan record
    scan = {
        "id": scan_id_counter,
        "user_id": current_user["id"],
        "sender": request.sender,
        "message": request.message,
        "message_preview": request.message[:100] + "..." if len(request.message) > 100 else request.message,
        "platform": request.platform,
        "risk_level": result["risk_level"],
        "reason": result["reason"],
        "scam_type": result.get("scam_type"),
        "confidence": result["confidence"],
        "created_at": datetime.utcnow()
    }
    
    # Store scan
    if current_user["id"] not in scans_db:
        scans_db[current_user["id"]] = []
    scans_db[current_user["id"]].append(scan)
    scan_id_counter += 1
    
    return ScanResponse(**scan)


@router.get("/history", response_model=list[ScanResponse])
async def get_history(
    limit: int = 50,
    risk_level: RiskLevel | None = None,
    current_user: dict = Depends(get_current_user)
):
    """Get scan history for current user"""
    user_scans = scans_db.get(current_user["id"], [])
    
    # Filter by risk level if specified
    if risk_level:
        user_scans = [s for s in user_scans if s["risk_level"] == risk_level]
    
    # Sort by date (newest first) and limit
    user_scans = sorted(user_scans, key=lambda x: x["created_at"], reverse=True)[:limit]
    
    return [ScanResponse(**scan) for scan in user_scans]


@router.get("/{scan_id}", response_model=ScanResponse)
async def get_scan(
    scan_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Get a specific scan by ID"""
    user_scans = scans_db.get(current_user["id"], [])
    
    for scan in user_scans:
        if scan["id"] == scan_id:
            return ScanResponse(**scan)
    
    raise HTTPException(status_code=404, detail="Scan not found")


@router.delete("/{scan_id}")
async def delete_scan(
    scan_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Delete a scan"""
    user_scans = scans_db.get(current_user["id"], [])
    
    for i, scan in enumerate(user_scans):
        if scan["id"] == scan_id:
            del user_scans[i]
            return {"message": "Scan deleted"}
    
    raise HTTPException(status_code=404, detail="Scan not found")
