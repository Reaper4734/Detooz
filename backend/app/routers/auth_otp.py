"""
OTP Authentication Router
Endpoints for Email OTP and Firebase Phone OTP authentication
"""
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import timedelta
import re
import logging

from app.db import get_db
from app.models import User
from app.config import settings
from app.services.otp_service import OTPService, EmailService, SMSService
from app.services.firebase_service import FirebaseService
from app.routers.auth import create_access_token

router = APIRouter()
logger = logging.getLogger(__name__)


# ----- Request/Response Models -----

class SendEmailOTPRequest(BaseModel):
    email: EmailStr


class VerifyEmailOTPRequest(BaseModel):
    email: EmailStr
    otp: str
    
    @field_validator('otp')
    @classmethod
    def validate_otp(cls, v):
        if not v.isdigit() or len(v) != 6:
            raise ValueError('OTP must be 6 digits')
        return v


class OTPResponse(BaseModel):
    success: bool
    message: str
    resend_in_seconds: int = 0


class VerifyOnlyResponse(BaseModel):
    """Response for verify-only endpoints (no user creation)"""
    success: bool
    message: str
    verified: bool = False
    verification_token: str | None = None


class AuthTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    is_new_user: bool
    email: str | None = None


# ----- Email OTP Endpoints -----


@router.post("/verify-email-only", response_model=VerifyOnlyResponse)
async def verify_email_only(request: VerifyEmailOTPRequest):
    """
    Verify email OTP WITHOUT creating a user or returning a token.
    
    Use this during REGISTRATION flow to verify email before account creation.
    For OTP-based LOGIN, use /verify-email-otp instead.
    """
    email = request.email.lower().strip()
    
    # Verify OTP
    success, message = OTPService.verify_otp(email, request.otp)
    
    if not success:
        return VerifyOnlyResponse(
            success=False,
            message=message,
            verified=False
        )
    
    # Generate verification token (short-lived, 1 hour)
    # This token proves that the email was verified by our backend
    verification_token = create_access_token(
        data={"sub": email, "type": "email_verification"},
        expires_delta=timedelta(hours=1)
    )
    
    return VerifyOnlyResponse(
        success=True,
        message="Email verified successfully",
        verified=True,
        verification_token=verification_token
    )


@router.post("/send-email-otp", response_model=OTPResponse)
async def send_email_otp(request: SendEmailOTPRequest):
    """
    Send OTP to email address for verification
    
    - Uses Gmail SMTP (500 emails/day free)
    - OTP expires in 5 minutes
    - Rate limited: 1 OTP per 30 seconds per email
    """
    email = request.email.lower().strip()
    
    # Check rate limit
    can_resend, wait_seconds = OTPService.can_resend(email)
    if not can_resend:
        return OTPResponse(
            success=False,
            message=f"Please wait before requesting another OTP",
            resend_in_seconds=wait_seconds
        )
    
    # Generate and store OTP
    otp = OTPService.generate_otp()
    OTPService.store_otp(email, otp)
    
    # Send email
    success = EmailService.send_otp_email(email, otp)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send OTP email. Please try again."
        )
    
    return OTPResponse(
        success=True,
        message="OTP sent to your email"
    )


@router.post("/verify-email-otp", response_model=AuthTokenResponse)
async def verify_email_otp(
    request: VerifyEmailOTPRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Verify email OTP and return JWT token
    
    - If user exists: return token
    - If new user: create user and return token
    """
    email = request.email.lower().strip()
    
    # Verify OTP
    success, message = OTPService.verify_otp(email, request.otp)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )
    
    # Get or create user
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    
    is_new_user = False
    
    if not user:
        # Create new user with minimal info (can complete profile later)
        # Email is already verified via OTP - no grace period needed
        user = User(
            email=email,
            password_hash="",  # OTP-only users don't have passwords
            first_name="",
            last_name="",
            email_verified=True  # Already verified via OTP
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
        is_new_user = True
        logger.info(f"New user created via email OTP: {email[:3]}***")
    else:
        # Mark email as verified
        user.email_verified = True
        await db.commit()
    
    # Generate JWT
    access_token = create_access_token(
        data={"sub": user.email},
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    
    return AuthTokenResponse(
        access_token=access_token,
        user_id=user.id,
        is_new_user=is_new_user,
        email=user.email
    )





# ----- Resend OTP Endpoint -----

@router.post("/resend-email-otp", response_model=OTPResponse)
async def resend_email_otp(request: SendEmailOTPRequest):
    """Resend OTP to email (alias for send-email-otp with rate limiting)"""
    return await send_email_otp(request)
