from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, scan, guardian, sms
from app.db import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup"""
    await init_db()
    yield


app = FastAPI(
    title="Detooz API",
    description="AI-powered scam detection backend",
    version="1.0.0",
    lifespan=lifespan
)

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
app.include_router(guardian.router, prefix="/api/guardian", tags=["Guardians"])
app.include_router(sms.router, prefix="/api/sms", tags=["SMS Detection"])


@app.get("/")
async def root():
    return {"message": "Detooz API is running", "version": "1.0.0"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
