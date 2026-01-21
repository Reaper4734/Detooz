"""
Blacklist Manager Service
Handles automatic blacklist population from AI detections
and export for LLM training
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
import hashlib
import json
import re
from typing import Optional, Dict, List
from app.models import Blacklist
from app.core.redis_client import redis_client

class BlacklistManager:
    """Manages automatic blacklist updates and training data export"""
    
    def __init__(self, cache_size: int = 1000):
        # We no longer use local memory cache (self.cache) to support multi-worker scaling
        # Redis is now the primary cache layer
        pass
    
    @staticmethod
    def normalize_value(value: str, value_type: str) -> str:
        """Normalize value for consistent storage"""
        if value_type == "phone":
            # Remove all non-digits, keep + at start
            digits = re.sub(r'[^\d+]', '', value)
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
            value = value.lower().strip()
            if '/' in value:
                from urllib.parse import urlparse
                parsed = urlparse(f"http://{value}" if not value.startswith('http') else value)
                value = parsed.netloc or parsed.path.split('/')[0]
            return value
            
        return value.strip()

    @staticmethod
    def compute_hash(value: str) -> str:
        """SHA256 hash for fast lookup"""
        return hashlib.sha256(value.encode()).hexdigest()

    async def auto_blacklist(self, value: str, content_type: str, source: str, db: AsyncSession, **kwargs) -> bool:
        """
        Add persistent blacklist entry and invalidate cache.
        Returns True if added, False if already exists.
        """
        if content_type not in ["url", "phone", "domain"]:
            return False
            
        normalized = self.normalize_value(value, content_type)
        value_hash = self.compute_hash(normalized)
        
        # Check if exists in DB
        result = await db.execute(
            select(Blacklist).where(
                Blacklist.value_hash == value_hash,
                Blacklist.type == content_type
            )
        )
        existing = result.scalar_one_or_none()
        
        if existing:
            existing.reports_count += 1
            existing.last_reported_at = datetime.utcnow()
            await db.commit()
            return False
            
        # Add new entry
        new_entry = Blacklist(
            type=content_type,
            value=normalized,
            value_hash=value_hash,
            source=source,
            reports_count=1,
            is_verified=False,  # Needs manual review or high confidence
            
            # Privacy-Aware Training Data
            full_message=kwargs.get("full_message") if kwargs.get("user_consented") else None,
            ai_reasoning=kwargs.get("ai_reasoning") if kwargs.get("user_consented") else None,
            scam_type=kwargs.get("scam_type"),
            confidence_score=kwargs.get("confidence"),
            language=kwargs.get("language", "en"),
            features_detected=json.dumps(kwargs.get("features", {})) if kwargs.get("user_consented") else None
        )
        db.add(new_entry)
        await db.commit()
        
        # Invalidate Cache (Delete key so next fetch gets new data)
        # Redis Key: bl:{value_hash}
        redis_client.delete(f"bl:{value_hash}")
        
        return True

    async def auto_blacklist_from_message(self, message: str, ai_reasoning: str, scam_type: str, confidence: float, user_consented: bool, db: AsyncSession) -> int:
        """
        Extract entities from message and blacklist them automatically
        """
        if confidence < 0.70:
            return 0
            
        count = 0
        
        # Extract URLs
        urls = re.findall(r'https?://[^\s<>"]+|www\.[^\s<>"]+', message)
        features = {"extracted_entities": urls}
        
        for url in urls:
            added = await self.auto_blacklist(
                value=url, 
                content_type="url", 
                source="ai_auto", 
                db=db,
                full_message=message,
                ai_reasoning=ai_reasoning,
                scam_type=scam_type,
                confidence=confidence,
                user_consented=user_consented,
                features=features,
                language="en" # Detect language if possible
            )
            if added: count += 1

        # Extract Phones (Simplified regex)
        phones = re.findall(r'(?:\+91|91)?[6-9]\d{9}', message)
        for phone in phones:
            added = await self.auto_blacklist(
                value=phone, 
                content_type="phone", 
                source="ai_auto", 
                db=db,
                full_message=message,
                ai_reasoning=ai_reasoning,
                scam_type=scam_type,
                confidence=confidence,
                user_consented=user_consented,
                features=features,
                language="en"
            )
            if added: count += 1
        
        return count
    
    async def check_blacklist(self, value: str, content_type: str, db: AsyncSession) -> Dict:
        """
        Check if value is blacklisted.
        Priority: Redis Cache -> Database
        """
        if content_type not in ["url", "phone", "domain"]:
            return {"is_blacklisted": False, "reports_count": 0}
            
        normalized = self.normalize_value(value, content_type)
        value_hash = self.compute_hash(normalized)
        
        # 1. Check Redis Cache
        cached_json = redis_client.get(f"bl:{value_hash}")
        if cached_json:
            try:
                return json.loads(cached_json)
            except json.JSONDecodeError:
                pass # Fall through to DB
            
        # 2. Check DB
        result = await db.execute(
            select(Blacklist).where(
                Blacklist.value_hash == value_hash,
                Blacklist.type == content_type
            )
        )
        entry = result.scalar_one_or_none()
        
        if entry:
            res = {
                "is_blacklisted": True,
                "reports_count": entry.reports_count,
                "scam_type": entry.scam_type,
                "confidence": entry.confidence_score,
                "is_verified": entry.is_verified,
                "risk_boost": 0.3 if entry.is_verified else 0.2
            }
        else:
            res = {"is_blacklisted": False, "reports_count": 0, "risk_boost": 0}
            
        # 3. Update Redis (TTL: 1 Hour)
        redis_client.setex(f"bl:{value_hash}", 3600, json.dumps(res))
        
        return res

# Global instance
blacklist_manager = BlacklistManager()
