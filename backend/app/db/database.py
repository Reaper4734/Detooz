from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings
import os
import logging

logger = logging.getLogger(__name__)

# Handle both SQLite and PostgreSQL
if settings.DATABASE_URL.startswith("sqlite"):
    DATABASE_URL = settings.DATABASE_URL
    # Extract file path for migrations
    DB_FILE_PATH = settings.DATABASE_URL.replace("sqlite+aiosqlite:///", "").replace("sqlite:///", "")
else:
    # Convert sync PostgreSQL URL to async
    DATABASE_URL = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")
    DB_FILE_PATH = None

engine = create_async_engine(DATABASE_URL, echo=settings.DEBUG)

async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)


class Base(DeclarativeBase):
    pass


async def get_db():
    """Dependency for getting database session"""
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    """Initialize database tables with automatic migration"""
    logger.info("Initializing database...")
    
    # Run migrations first (SQLite only)
    if DB_FILE_PATH and os.path.exists(DB_FILE_PATH):
        logger.info("Running database migrations...")
        try:
            from app.db.migrations import run_migrations
            run_migrations(DB_FILE_PATH)
            logger.info("Migrations complete")
        except Exception as e:
            logger.warning(f"Migration warning: {e}")
    
    # Then create any new tables
    try:
        async with engine.begin() as conn:
            logger.info("Running metadata create_all...")
            await conn.run_sync(Base.metadata.create_all)
            logger.info("Database initialization successful.")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        raise


