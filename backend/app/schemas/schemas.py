from pydantic import BaseModel, EmailStr
from datetime import datetime
from app.models import PlatformType, RiskLevel


# ============== User Schemas ==============

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str
    phone: str | None = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    phone: str | None
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    email: str | None = None


# ============== Guardian Schemas ==============

class GuardianCreate(BaseModel):
    name: str
    phone: str
    callmebot_apikey: str | None = None
    telegram_chat_id: str | None = None


class GuardianUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    callmebot_apikey: str | None = None
    telegram_chat_id: str | None = None


class GuardianResponse(BaseModel):
    id: int
    name: str
    phone: str
    telegram_chat_id: str | None
    is_verified: bool
    last_alert_sent: datetime | None
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============== Scan Schemas ==============

class ScanRequest(BaseModel):
    message: str
    sender: str
    platform: PlatformType = PlatformType.SMS


class ScanResponse(BaseModel):
    id: int
    sender: str | None
    message_preview: str | None
    platform: PlatformType
    risk_level: RiskLevel
    risk_reason: str | None
    scam_type: str | None
    confidence: float | None
    guardian_alerted: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class ScanDetail(ScanResponse):
    message: str | None
    is_blocked: bool
