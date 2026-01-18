"""Guardian authentication router - separate login system for guardians"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta
from passlib.context import CryptContext
from jose import jwt
from pydantic import BaseModel, EmailStr

from app.db import get_db
from app.models import GuardianAccount
from app.config import settings

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ============ SCHEMAS ============

class GuardianRegister(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    middle_name: str | None = None
    last_name: str
    phone: str | None = None
    country_code: str | None = "+91"


class GuardianResponse(BaseModel):
    id: int
    email: str
    first_name: str
    middle_name: str | None
    last_name: str
    phone: str | None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    guardian_id: int
    name: str


# ============ HELPERS ============

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_guardian_token(guardian_id: int, email: str) -> str:
    """Create JWT token for guardian (different from user tokens)"""
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 24)  # 24 hours
    to_encode = {
        "sub": email,
        "guardian_id": guardian_id,
        "type": "guardian",  # Distinguish from user tokens
        "exp": expire
    }
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


async def get_current_guardian(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(lambda: None)  # Will be replaced with proper OAuth2
) -> GuardianAccount:
    """Dependency to get current guardian from token"""
    from fastapi.security import OAuth2PasswordBearer
    oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/guardian-auth/login")
    # This will be properly implemented when we add the middleware
    pass


# ============ ENDPOINTS ============

@router.post("/register", response_model=TokenResponse)
async def register_guardian(
    data: GuardianRegister,
    db: AsyncSession = Depends(get_db)
):
    """Register a new guardian account"""
    
    # Normalize
    normalized_email = data.email.lower().strip()
    
    # Check if email already exists
    result = await db.execute(
        select(GuardianAccount).where(GuardianAccount.email == normalized_email)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered as guardian"
        )
        
    # Check phone
    if data.phone:
        normalized_phone = data.phone.strip()
        res_p = await db.execute(select(GuardianAccount).where(GuardianAccount.phone == normalized_phone))
        if res_p.scalar_one_or_none():
             raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered"
            )
    
    # Create guardian account
    guardian = GuardianAccount(
        email=normalized_email,
        password_hash=get_password_hash(data.password),
        first_name=data.first_name,
        middle_name=data.middle_name,
        last_name=data.last_name,
        phone=data.phone.strip() if data.phone else None,
        country_code=data.country_code
    )
    
    db.add(guardian)
    await db.commit()
    await db.refresh(guardian)
    
    # Create token
    token = create_guardian_token(guardian.id, guardian.email)
    
    return TokenResponse(
        access_token=token,
        guardian_id=guardian.id,
        name=f"{guardian.first_name} {guardian.last_name}"
    )


@router.post("/login", response_model=TokenResponse)
async def login_guardian(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    """Login as guardian"""
    
    result = await db.execute(
        select(GuardianAccount).where(GuardianAccount.email == form_data.username)
    )
    guardian = result.scalar_one_or_none()
    
    if not guardian or not verify_password(form_data.password, guardian.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    if not guardian.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Guardian account is deactivated"
        )
    
    token = create_guardian_token(guardian.id, guardian.email)
    
    return TokenResponse(
        access_token=token,
        guardian_id=guardian.id,
        name=guardian.name
    )


@router.get("/me", response_model=GuardianResponse)
async def get_guardian_profile(
    db: AsyncSession = Depends(get_db),
    # Note: We need to implement proper token verification
    # For now, this is a placeholder that will be completed
):
    """Get current guardian's profile"""
    # This requires proper JWT verification middleware
    # Will be implemented with get_current_guardian dependency
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Guardian auth middleware pending"
    )
