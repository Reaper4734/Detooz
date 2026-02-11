"""
Google Sign-In Authentication
Handles Google OAuth token verification and identity linking
"""
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import timedelta, datetime
import logging

from app.db import get_db
from app.models import User
from app.config import settings
from app.services.firebase_service import FirebaseService
from app.routers.auth import create_access_token

router = APIRouter()
logger = logging.getLogger(__name__)


class GoogleSignInRequest(BaseModel):
    id_token: str  # Firebase ID token from Google Sign-In


class GoogleSignInResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    is_new_user: bool
    email: str
    display_name: str | None = None
    needs_profile_completion: bool = False


from starlette.concurrency import run_in_threadpool

@router.post("/google-signin", response_model=GoogleSignInResponse)
async def google_signin(
    request: GoogleSignInRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Authenticate with Google Sign-In
    
    Flow:
    1. Client uses Firebase Google Sign-In
    2. Client sends Firebase ID token
    3. We verify token and extract Google user info
    4. We find or create user, handling identity linking
    5. Return JWT
    
    Identity Linking:
    - If email already exists (Email/Pass user), link Google account
    - If google_uid exists, login existing user
    - Otherwise, create new user
    """
    logger.info(f"Google Sign-In attempt: token_len={len(request.id_token)}")
    
    # Verify Firebase token (works for Google Sign-In too)
    # Run in threadpool because verify_id_token is blocking I/O
    firebase_user = await run_in_threadpool(FirebaseService.verify_id_token, request.id_token)
    
    if not firebase_user:
        logger.error("Firebase token verification returned None - check firebase_service.py logs")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Google Sign-In token"
        )
    
    email = firebase_user.get('email')
    google_uid = firebase_user.get('uid')
    display_name = firebase_user.get('name', '')
    
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No email in Google account"
        )
    
    email = email.lower().strip()
    is_new_user = False
    needs_profile_completion = False
    
    # Check if user exists by google_uid
    result = await db.execute(select(User).where(User.google_uid == google_uid))
    user = result.scalar_one_or_none()
    
    if user:
        # Existing Google user - just login
        logger.info(f"Google Sign-In: Existing user {email[:3]}***")
    else:
        # Check if email exists (identity linking scenario)
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        
        if user:
            # Link Google account to existing user
            user.google_uid = google_uid
            user.email_verified = True  # Google verified the email
            await db.commit()
            logger.info(f"Google Sign-In: Linked to existing account {email[:3]}***")
        else:
            # Create new user
            # Parse display name into first/last
            name_parts = display_name.split(' ', 1) if display_name else ['', '']
            first_name = name_parts[0] if name_parts else ''
            last_name = name_parts[1] if len(name_parts) > 1 else ''
            
            # Google Sign-In - email is verified by Google
            # Phone may or may not be provided by Google
            phone_from_google = firebase_user.get('phone_number')
            
            # If phone is missing, set grace period for user to verify later
            # Frontend will show verification popup, if user rejects → grace period
            grace_period = None
            if not phone_from_google:
                grace_period = datetime.utcnow() + timedelta(days=30)
            
            user = User(
                email=email,
                password_hash="google_auth_placeholder",  # Dummy hash for Google Auth users
                first_name=first_name,
                last_name=last_name,
                google_uid=google_uid,
                phone=phone_from_google,
                email_verified=True,  # Google always verifies email
                phone_verified=bool(phone_from_google),  # True only if Google provided phone
                verification_grace_period_end=grace_period,
                is_active=True
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
            
            is_new_user = True
            needs_profile_completion = not first_name
            logger.info(f"Google Sign-In: New user created {email[:3]}***")
    
    # Generate JWT
    access_token = create_access_token(
        data={"sub": user.email},
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    
    return GoogleSignInResponse(
        access_token=access_token,
        user_id=user.id,
        is_new_user=is_new_user,
        email=user.email,
        display_name=f"{user.first_name} {user.last_name}".strip() or None,
        needs_profile_completion=needs_profile_completion,
    )
