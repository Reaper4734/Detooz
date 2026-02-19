from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Detooz"
    DEBUG: bool = False
    
    # Database (SQLite for local, PostgreSQL for production)
    DATABASE_URL: str = "sqlite+aiosqlite:///./detooz.db"
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379"
    
    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 43200  # 30 days (mobile app)
    
    # AI APIs (FREE tiers)
    GROQ_API_KEY: str = ""
    GEMINI_API_KEY: str = ""
    OPENROUTER_API_KEY: str = ""
    
    # Firebase Cloud Messaging (for push notifications)
    FCM_SERVER_KEY: str = ""
    
    # SMTP Settings for Email OTP
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    
    # CallMeBot (FREE WhatsApp alerts)
    CALLMEBOT_ENABLED: bool = True
    
    # Telegram Bot (FREE, unlimited - recommended!)
    # Create bot via @BotFather on Telegram
    TELEGRAM_BOT_TOKEN: str = ""
    
    # Fast2SMS (FREE 10 SMS/day for phone OTP)
    FAST2SMS_API_KEY: str = ""
    
    model_config = {
        "env_file": ".env",
        "extra": "ignore"
    }

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.SECRET_KEY == "your-secret-key-change-in-production":
            if not self.DEBUG:
                raise ValueError(
                    "CRITICAL SECURITY ERROR: You are running in production (DEBUG=False) "
                    "with the default SECRET_KEY. Please set a secure SECRET_KEY in your .env file."
                )
            else:
                print("WARNING: Using default SECRET_KEY. This is unsafe for production but allowed in DEBUG mode.")


@lru_cache()
def get_settings():
    return Settings()


settings = get_settings()
