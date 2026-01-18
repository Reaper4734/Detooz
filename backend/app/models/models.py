from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Float, Text, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from app.db.database import Base
import enum


class PlatformType(str, enum.Enum):
    SMS = "SMS"
    WHATSAPP = "WHATSAPP"
    TELEGRAM = "TELEGRAM"


class RiskLevel(str, enum.Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100), nullable=False)
    middle_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=True)
    country_code = Column(String(5), default="+91", nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    guardians = relationship("Guardian", back_populates="user", cascade="all, delete-orphan")
    scans = relationship("Scan", back_populates="user", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User {self.email}>"


class Guardian(Base):
    __tablename__ = "guardians"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(255), nullable=False)
    phone = Column(String(20), nullable=False)
    callmebot_apikey = Column(String(50), nullable=True)
    telegram_chat_id = Column(String(50), nullable=True)  # For Telegram alerts
    is_verified = Column(Boolean, default=False)
    last_alert_sent = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="guardians")
    
    def __repr__(self):
        return f"<Guardian {self.name}>"


class Scan(Base):
    __tablename__ = "scans"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    sender = Column(String(50), nullable=True)
    message = Column(Text, nullable=True)
    message_preview = Column(String(200), nullable=True)
    platform = Column(SQLEnum(PlatformType), default=PlatformType.SMS)
    risk_level = Column(SQLEnum(RiskLevel), nullable=False)
    risk_reason = Column(Text, nullable=True)
    scam_type = Column(String(50), nullable=True)
    confidence = Column(Float, nullable=True)
    is_blocked = Column(Boolean, default=False)
    guardian_alerted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    
    # Relationships
    user = relationship("User", back_populates="scans")
    
    def __repr__(self):
        return f"<Scan {self.id} - {self.risk_level}>"


class TrustedSender(Base):
    """Trusted senders bypass scam detection alerts"""
    __tablename__ = "trusted_senders"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    sender = Column(String(100), nullable=False, index=True)
    name = Column(String(255), nullable=True)  # Optional friendly name
    reason = Column(String(255), nullable=True)  # Why they're trusted
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user = relationship("User", backref="trusted_senders")
    
    def __repr__(self):
        return f"<TrustedSender {self.sender}>"


class Feedback(Base):
    """User feedback on scan results for model improvement"""
    __tablename__ = "feedback"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    scan_id = Column(Integer, ForeignKey("scans.id", ondelete="CASCADE"), nullable=False)
    user_verdict = Column(String(20), nullable=False)  # "safe", "scam", "unsure"
    original_verdict = Column(String(20), nullable=True)  # What the AI said
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user = relationship("User", backref="feedback")
    scan = relationship("Scan", backref="feedback")
    
    def __repr__(self):
        return f"<Feedback scan={self.scan_id} verdict={self.user_verdict}>"


class Blacklist(Base):
    """Known scam URLs, phone numbers, and domains"""
    __tablename__ = "blacklist"
    
    id = Column(Integer, primary_key=True, index=True)
    type = Column(String(20), nullable=False, index=True)  # "url", "phone", "domain"
    value = Column(String(500), nullable=False)
    value_hash = Column(String(64), nullable=False, index=True)  # SHA256 hash for fast lookup
    source = Column(String(50), nullable=True)  # "community", "system", "verified"
    reports_count = Column(Integer, default=1)
    first_reported_at = Column(DateTime, default=datetime.utcnow)
    last_reported_at = Column(DateTime, default=datetime.utcnow)
    is_verified = Column(Boolean, default=False)
    
    def __repr__(self):
        return f"<Blacklist {self.type}: {self.value[:30]}>"


class UserSettings(Base):
    """User preferences and settings"""
    __tablename__ = "user_settings"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    language = Column(String(10), default="en")  # "en", "hi", etc.
    auto_block_high_risk = Column(Boolean, default=True)
    alert_guardians_threshold = Column(String(20), default="HIGH")  # "HIGH", "MEDIUM", "ALL"
    receive_tips = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user = relationship("User", backref="settings")
    
    def __repr__(self):
        return f"<UserSettings user={self.user_id}>"


# ============ GUARDIAN ALERT SYSTEM ============

class GuardianAccount(Base):
    """Separate login account for guardians (not regular users)"""
    __tablename__ = "guardian_accounts"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100), nullable=False)
    middle_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=True)
    country_code = Column(String(5), default="+91", nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    links = relationship("GuardianLink", back_populates="guardian_account", cascade="all, delete-orphan")
    alerts = relationship("GuardianAlert", back_populates="guardian_account", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<GuardianAccount {self.email}>"


class GuardianLink(Base):
    """Links a guardian account to a user they are protecting (via OTP verification)"""
    __tablename__ = "guardian_links"
    
    id = Column(Integer, primary_key=True, index=True)
    guardian_account_id = Column(Integer, ForeignKey("guardian_accounts.id", ondelete="CASCADE"), nullable=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # OTP verification
    otp_code = Column(String(6), nullable=True)  # 6-digit OTP
    otp_expires_at = Column(DateTime, nullable=True)  # Expires in 10 minutes
    
    # Status: pending (OTP generated), active (verified), revoked
    status = Column(String(20), default="pending")
    
    created_at = Column(DateTime, default=datetime.utcnow)
    verified_at = Column(DateTime, nullable=True)
    
    # Relationships
    guardian_account = relationship("GuardianAccount", back_populates="links")
    user = relationship("User", backref="guardian_links")
    
    def __repr__(self):
        return f"<GuardianLink user={self.user_id} guardian={self.guardian_account_id} status={self.status}>"


class GuardianAlert(Base):
    """Alert sent to guardian when protected user receives high-risk SMS"""
    __tablename__ = "guardian_alerts"
    
    id = Column(Integer, primary_key=True, index=True)
    guardian_account_id = Column(Integer, ForeignKey("guardian_accounts.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    scan_id = Column(Integer, ForeignKey("scans.id", ondelete="CASCADE"), nullable=False)
    
    # Alert status: pending, seen, actioned, dismissed
    status = Column(String(20), default="pending")
    action_taken = Column(String(100), nullable=True)  # What guardian did
    action_notes = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    seen_at = Column(DateTime, nullable=True)
    actioned_at = Column(DateTime, nullable=True)
    
    # Relationships
    guardian_account = relationship("GuardianAccount", back_populates="alerts")
    user = relationship("User", backref="guardian_alerts")
    scan = relationship("Scan", backref="guardian_alerts")
    
    def __repr__(self):
        return f"<GuardianAlert id={self.id} status={self.status}>"

