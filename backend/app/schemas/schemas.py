from pydantic import BaseModel, EmailStr, validator
from datetime import datetime
from app.models import PlatformType, RiskLevel


# ============== User Schemas ==============

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    middle_name: str | None = None
    last_name: str
    phone: str | None = None
    country_code: str | None = "+91"

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        if not any(c in '@$!%*#?&' for c in v):
            raise ValueError('Password must contain at least one special character (@$!%*#?&)')
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: int
    email: str
    first_name: str
    middle_name: str | None
    last_name: str
    phone: str | None
    country_code: str | None
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
    first_name: str
    middle_name: str | None = None
    last_name: str
    phone: str
    country_code: str | None = "+91"
    callmebot_apikey: str | None = None
    telegram_chat_id: str | None = None


class GuardianUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    callmebot_apikey: str | None = None
    telegram_chat_id: str | None = None


class GuardianResponse(BaseModel):
    id: int
    first_name: str
    middle_name: str | None
    last_name: str
    phone: str
    country_code: str | None
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
