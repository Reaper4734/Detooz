"""
Reputation Database API
Check and report scam URLs, phone numbers, and domains
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from datetime import datetime
from pydantic import BaseModel
import hashlib
import re
from urllib.parse import urlparse
from app.db import get_db
from app.models import User, Blacklist
from app.routers.auth import get_current_user
from app.services.blacklist_manager import blacklist_manager

router = APIRouter()


# ============== Schemas ==============

class ReputationCheck(BaseModel):
    """Result of reputation check"""
    value: str
    type: str
    is_blacklisted: bool
    reports_count: int
    is_verified: bool
    risk_score: float  # 0.0 - 1.0


class ReportRequest(BaseModel):
    """Report a scam URL/phone/domain"""
    value: str
    type: str  # "url", "phone", "domain"
    reason: str | None = None


class BlacklistEntry(BaseModel):
    """Blacklist entry response"""
    type: str
    value: str
    reports_count: int
    is_verified: bool
    first_reported_at: datetime
    
    class Config:
        from_attributes = True


# ============== Helper Functions ==============

def normalize_value(value: str, value_type: str) -> str:
    """Normalize value for consistent storage and lookup"""
    
    if value_type == "phone":
        # Remove all non-digits, keep + at start
        digits = re.sub(r'[^\d+]', '', value)
        # If starts with +91, keep it, otherwise add +91 for India
        if not digits.startswith('+'):
            if digits.startswith('91') and len(digits) == 12:
                digits = '+' + digits
            else:
                digits = '+91' + digits[-10:]  # Take last 10 digits
        return digits
    
    elif value_type == "url":
        # Remove protocol, lowercase, remove trailing slash
        value = value.lower().strip()
        value = re.sub(r'^https?://', '', value)
        value = re.sub(r'/$', '', value)
        return value
    
    elif value_type == "domain":
        # Extract domain, lowercase
        value = value.lower().strip()
        if '/' in value:
            parsed = urlparse(f"http://{value}" if not value.startswith('http') else value)
            value = parsed.netloc or parsed.path.split('/')[0]
        return value
    
    return value.lower().strip()


def compute_hash(value: str) -> str:
    """Compute SHA256 hash of normalized value"""
    return hashlib.sha256(value.encode()).hexdigest()


# ============== Endpoints ==============

@router.get("/check")
async def check_reputation(
    url: str | None = Query(None, description="URL to check"),
    phone: str | None = Query(None, description="Phone number to check"),
    domain: str | None = Query(None, description="Domain to check"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> ReputationCheck:
    """Check if a URL, phone number, or domain is in the blacklist"""
    
    # Determine what to check
    if url:
        value_type = "url"
        value = url
    elif phone:
        value_type = "phone"
        value = phone
    elif domain:
        value_type = "domain"
        value = domain
    else:
        raise HTTPException(status_code=400, detail="Provide url, phone, or domain parameter")
    
    # Normalize and hash
    normalized = normalize_value(value, value_type)
    value_hash = compute_hash(normalized)
    
    # Look up in database
    result = await db.execute(
        select(Blacklist).where(
            Blacklist.value_hash == value_hash,
            Blacklist.type == value_type
        )
    )
    entry = result.scalar_one_or_none()
    
    if entry:
        # Calculate risk score based on reports and verification
        base_score = 0.5
        if entry.is_verified:
            base_score = 0.9
        score = min(base_score + (entry.reports_count * 0.05), 1.0)
        
        return ReputationCheck(
            value=value,
            type=value_type,
            is_blacklisted=True,
            reports_count=entry.reports_count,
            is_verified=entry.is_verified,
            risk_score=round(score, 2)
        )
    
    return ReputationCheck(
        value=value,
        type=value_type,
        is_blacklisted=False,
        reports_count=0,
        is_verified=False,
        risk_score=0.0
    )


@router.post("/report")
async def report_scam(
    report: ReportRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Report a scam URL, phone number, or domain"""
    
    # Validate type
    if report.type not in ["url", "phone", "domain"]:
        raise HTTPException(status_code=400, detail="Type must be 'url', 'phone', or 'domain'")
    
    # Normalize and hash
    normalized = normalize_value(report.value, report.type)
    value_hash = compute_hash(normalized)
    
    # Check if already exists
    result = await db.execute(
        select(Blacklist).where(
            Blacklist.value_hash == value_hash,
            Blacklist.type == report.type
        )
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        # Increment report count
        existing.reports_count += 1
        existing.last_reported_at = datetime.utcnow()
        await db.commit()
        
        return {
            "message": "Report added to existing entry",
            "reports_count": existing.reports_count
        }
    
    # Create new entry
    entry = Blacklist(
        type=report.type,
        value=normalized,
        value_hash=value_hash,
        source="community",
        reports_count=1
    )
    
    db.add(entry)
    await db.commit()
    
    return {"message": "Scam reported successfully", "reports_count": 1}


@router.get("/recent", response_model=list[BlacklistEntry])
async def get_recent_reports(
    limit: int = 20,
    type: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get recently reported scams"""
    
    query = select(Blacklist).order_by(Blacklist.last_reported_at.desc())
    
    if type:
        if type not in ["url", "phone", "domain"]:
            raise HTTPException(status_code=400, detail="Invalid type filter")
        query = query.where(Blacklist.type == type)
    
    query = query.limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/verified", response_model=list[BlacklistEntry])
async def get_verified_scams(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get verified scam entries (high confidence)"""
    
    result = await db.execute(
        select(Blacklist)
        .where(Blacklist.is_verified == True)
        .order_by(Blacklist.reports_count.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/export/training-data")
async def export_training_data(
    format: str = "jsonl",  # "jsonl" or "csv"
    min_confidence: float = 0.70,
    verified_only: bool = False,
    limit: int = 10000,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Export blacklist data in LLM training format
    
    Formats:
    - jsonl: OpenAI fine-tuning format
    - csv: Tabular data format
    """
    
    if format not in ["jsonl", "csv"]:
        raise HTTPException(status_code=400, detail="Format must be 'jsonl' or 'csv'")
    
    training_data = await blacklist_manager.export_training_data(
        db=db,
        format=format,
        min_confidence=min_confidence,
        verified_only=verified_only,
        limit=limit
    )
    
    return {
        "format": format,
        "total_entries": len(training_data),
        "min_confidence": min_confidence,
        "verified_only": verified_only,
        "data": training_data
    }
