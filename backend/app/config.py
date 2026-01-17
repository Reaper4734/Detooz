from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Detooz"
    DEBUG: bool = True
    
    # Database (SQLite for local, PostgreSQL for production)
    DATABASE_URL: str = "sqlite+aiosqlite:///./detooz.db"
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379"
    
    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # AI APIs (FREE tiers)
    GROQ_API_KEY: str = ""
    GEMINI_API_KEY: str = ""
    OPENROUTER_API_KEY: str = ""
    
    # CallMeBot (FREE WhatsApp alerts)
    CALLMEBOT_ENABLED: bool = True
    
    # Telegram Bot (FREE, unlimited - recommended!)
    # Create bot via @BotFather on Telegram
    TELEGRAM_BOT_TOKEN: str = ""
    
    model_config = {
        "env_file": ".env",
        "extra": "ignore"
    }


@lru_cache()
def get_settings():
    return Settings()


settings = get_settings()
print(f"DEBUG: Groq Key Loaded: {'YES' if settings.GROQ_API_KEY else 'NO'}")
print(f"DEBUG: Groq Key Starts With: {settings.GROQ_API_KEY[:4] if settings.GROQ_API_KEY else 'N/A'}")
