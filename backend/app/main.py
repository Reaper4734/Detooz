from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, scan, sms, trusted_sender, user, feedback, reputation, manual_scan
from app.routers import guardian_link, guardian_alerts, admin, privacy
from app.db import init_db
# Import all models so they're registered with SQLAlchemy before init_db
from app.models import User, Scan, TrustedSender, Feedback, Blacklist, UserSettings, GuardianLink, GuardianAlert


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup"""
    await init_db()
    yield


app = FastAPI(
    title="Detooz API",
    description="AI-powered scam detection backend",
    version="1.3.0",  # Version bump for guardian system
    lifespan=lifespan
)

# Mount static files for image uploads
# Mount static files for image uploads
import os
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
uploads_dir = os.path.join(BASE_DIR, "static", "uploads")
os.makedirs(uploads_dir, exist_ok=True)

app.mount("/api/uploads", StaticFiles(directory=uploads_dir), name="uploads")

# CORS for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(scan.router, prefix="/api/scan", tags=["Scam Detection"])
app.include_router(sms.router, prefix="/api/sms", tags=["SMS Detection"])
app.include_router(trusted_sender.router, prefix="/api/trusted", tags=["Trusted Senders"])
app.include_router(user.router, prefix="/api/user", tags=["User"])
app.include_router(feedback.router, prefix="/api/feedback", tags=["Feedback"])
app.include_router(reputation.router, prefix="/api/reputation", tags=["Reputation Database"])
app.include_router(manual_scan.router, prefix="/api/manual", tags=["Manual Scan"])

# Guardian Alert System (New)
app.include_router(guardian_link.router, prefix="/api/guardian-link", tags=["Guardian Linking"])
app.include_router(guardian_alerts.router, prefix="/api/guardian-alerts", tags=["Guardian Alerts"])
app.include_router(admin.router, prefix="/api/admin", tags=["Admin Dashboard"])
app.include_router(privacy.router, prefix="/api/privacy", tags=["Privacy & Consent"])


@app.get("/")
async def root():
    return {"message": "Detooz API is running", "version": "1.2.0"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
