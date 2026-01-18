"""
Manual Scan API
Unified endpoint for manual fact-checking: text, URLs, phone numbers, images
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from pydantic import BaseModel
from typing import Optional, Literal
from app.db import get_db
from app.models import User, Scan, TrustedSender, Blacklist, PlatformType, RiskLevel
from app.routers.auth import get_current_user
from app.services.scam_detector import ScamDetector
from app.services.url_scraper import url_scraper
from app.services.explanation_engine import explanation_engine
from app.services.confidence_scorer import confidence_scorer
import hashlib
import re

router = APIRouter()
detector = ScamDetector()


# ============== Schemas ==============

class ManualScanRequest(BaseModel):
    """Request for manual scan"""
    content: str  # Text, URL, or phone number
    content_type: Literal["text", "url", "phone", "auto"] = "auto"


class ManualScanResult(BaseModel):
    """Complete manual scan result"""
    content: str
    content_type: str
    risk_level: str
    confidence: float
    reason: str
    scam_type: Optional[str]
    explanation: dict  # "Why Should I Care?" content
    reputation: Optional[dict]  # Reputation database result
    is_trusted: bool
    scan_id: Optional[int]


class ExplanationRequest(BaseModel):
    """Request explanation for a scan"""
    risk_level: str
    scam_type: Optional[str] = None
    language: str = "en"


# ============== Helper Functions ==============

def detect_content_type(content: str) -> str:
    """Auto-detect content type from input"""
    
    content = content.strip()
    
    # Check for URL
    url_pattern = r'^(https?://|www\.)[^\s]+'
    if re.match(url_pattern, content, re.IGNORECASE):
        return "url"
    
    # Check for phone number (Indian format)
    phone_pattern = r'^[\+]?[0-9]{10,13}$'
    digits_only = re.sub(r'[^\d+]', '', content)
    if re.match(phone_pattern, digits_only):
        return "phone"
    
    # Check if it's a domain
    domain_pattern = r'^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z]{2,}$'
    if re.match(domain_pattern, content):
        return "url"
    
    return "text"


async def check_reputation(content: str, content_type: str, db: AsyncSession) -> dict:
    """Check content against reputation database"""
    
    if content_type not in ["url", "phone"]:
        return {"is_blacklisted": False, "reports_count": 0}
    
    # Normalize and hash
    if content_type == "phone":
        normalized = url_scraper.normalize_phone(content)
    else:
        normalized = content.lower().strip()
        if normalized.startswith(('http://', 'https://')):
            normalized = re.sub(r'^https?://', '', normalized)
    
    value_hash = hashlib.sha256(normalized.encode()).hexdigest()
    
    # Check blacklist
    result = await db.execute(
        select(Blacklist).where(
            Blacklist.value_hash == value_hash,
            Blacklist.type == content_type
        )
    )
    entry = result.scalar_one_or_none()
    
    if entry:
        return {
            "is_blacklisted": True,
            "reports_count": entry.reports_count,
            "is_verified": entry.is_verified,
            "risk_boost": 0.3 if entry.is_verified else 0.2
        }
    
    return {"is_blacklisted": False, "reports_count": 0, "risk_boost": 0}


async def check_trusted(sender: str, user_id: int, db: AsyncSession) -> bool:
    """Check if sender is trusted by user"""
    result = await db.execute(
        select(TrustedSender).where(
            TrustedSender.user_id == user_id,
            TrustedSender.sender == sender
        )
    )
    return result.scalar_one_or_none() is not None


# ============== Endpoints ==============

@router.post("/analyze", response_model=ManualScanResult)
async def manual_scan(
    request: ManualScanRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Unified manual scan endpoint.
    Accepts text, URL, or phone number and returns comprehensive analysis.
    """
    
    content = request.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Content cannot be empty")
    
    # Auto-detect content type if needed
    content_type = request.content_type
    if content_type == "auto":
        content_type = detect_content_type(content)
    
    # Check reputation database
    reputation = await check_reputation(content, content_type, db)
    
    # Check if trusted (for phone numbers as "sender")
    is_trusted = False
    if content_type == "phone":
        is_trusted = await check_trusted(content, current_user.id, db)
    
    # Run appropriate analysis
    if content_type == "url":
        # URL analysis
        url_result = await url_scraper.analyze_url(content)
        
        result = {
            "risk_level": url_result["risk_level"],
            "reason": url_result["reason"],
            "confidence": url_result.get("confidence", 0.7),
            "scam_type": url_result.get("scam_type", "Suspicious URL" if url_result["risk_level"] == "HIGH" else None)
        }
        
    elif content_type == "phone":
        # Phone number analysis - check reputation
        if reputation["is_blacklisted"]:
            result = {
                "risk_level": "HIGH",
                "reason": f"Phone number reported {reputation['reports_count']} times as scam",
                "confidence": 0.85,
                "scam_type": "Reported Number"
            }
        elif is_trusted:
            result = {
                "risk_level": "LOW",
                "reason": "This number is in your trusted list",
                "confidence": 0.95,
                "scam_type": None
            }
        else:
            result = {
                "risk_level": "LOW",
                "reason": "No reports found for this number",
                "confidence": 0.6,
                "scam_type": None
            }
            
    else:
        # Text analysis using AI
        detection_result = await detector.analyze(content, "Manual Check")
        result = detection_result
    
    # Apply reputation boost if blacklisted
    if reputation.get("is_blacklisted") and result["risk_level"] != "HIGH":
        result["risk_level"] = "MEDIUM" if result["risk_level"] == "LOW" else result["risk_level"]
        result["reason"] += " (Also found in reputation database)"
    
    # Apply confidence calibration
    calibrated = confidence_scorer.calibrate_for_risk_level(
        result["risk_level"],
        result.get("confidence", 0.7)
    )
    
    # Get explanation
    explanation = explanation_engine.get_explanation(
        result["risk_level"],
        result.get("scam_type"),
        language="en"
    )
    
    # Create scan record
    scan = Scan(
        user_id=current_user.id,
        sender=f"Manual:{content_type}",
        message=content,
        message_preview=content[:200] if len(content) > 200 else content,
        platform=PlatformType.SMS,  # Using SMS as general platform
        risk_level=RiskLevel(result["risk_level"]),
        risk_reason=result["reason"],
        scam_type=result.get("scam_type"),
        confidence=calibrated["confidence"],
        is_blocked=False,
        guardian_alerted=False
    )
    
    db.add(scan)
    await db.commit()
    await db.refresh(scan)
    
    return ManualScanResult(
        content=content,
        content_type=content_type,
        risk_level=result["risk_level"],
        confidence=calibrated["confidence"],
        reason=result["reason"],
        scam_type=result.get("scam_type"),
        explanation=explanation,
        reputation=reputation if reputation["is_blacklisted"] else None,
        is_trusted=is_trusted,
        scan_id=scan.id
    )


@router.post("/explain")
async def get_explanation(
    request: ExplanationRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Get "Why Should I Care?" explanation for a risk level and scam type.
    Can be called independently of a scan.
    """
    
    explanation = explanation_engine.get_explanation(
        request.risk_level,
        request.scam_type,
        request.language
    )
    
    tip = explanation_engine.get_quick_tip(request.scam_type)
    
    return {
        **explanation,
        "quick_tip": tip
    }


@router.get("/scam-types")
async def list_scam_types(
    current_user: User = Depends(get_current_user)
):
    """Get list of all known scam types with brief descriptions"""
    
    all_types = explanation_engine.get_all_scam_types()
    
    result = []
    for scam_type in all_types:
        explanation = explanation_engine.get_explanation("HIGH", scam_type)
        result.append({
            "type": scam_type,
            "headline": explanation["headline"],
            "severity": explanation["severity"],
            "potential_loss": explanation["potential_loss"]
        })
    
    return result


@router.post("/analyze-url")
async def analyze_url_only(
    url: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Analyze a URL specifically (standalone endpoint).
    """
    
    result = await url_scraper.analyze_url(url)
    
    # Get explanation
    scam_type = result.get("scam_type")
    explanation = explanation_engine.get_explanation(
        result["risk_level"],
        scam_type
    )
    
    return {
        **result,
        "explanation": explanation
    }


@router.post("/check-phone")
async def check_phone_only(
    phone: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Check a phone number specifically (standalone endpoint).
    """
    
    normalized = url_scraper.normalize_phone(phone)
    
    # Check reputation
    reputation = await check_reputation(normalized, "phone", db)
    
    # Check if trusted
    is_trusted = await check_trusted(normalized, current_user.id, db)
    
    if reputation["is_blacklisted"]:
        risk_level = "HIGH"
        reason = f"Reported as scam {reputation['reports_count']} times"
    elif is_trusted:
        risk_level = "LOW"
        reason = "Marked as trusted by you"
    else:
        risk_level = "LOW"
        reason = "No negative reports found"
    
    explanation = explanation_engine.get_explanation(risk_level, None)
    
    return {
        "phone": phone,
        "normalized": normalized,
        "risk_level": risk_level,
        "reason": reason,
        "is_trusted": is_trusted,
        "reputation": reputation,
        "explanation": explanation
    }
