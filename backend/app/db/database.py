from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

# Handle both SQLite and PostgreSQL
if settings.DATABASE_URL.startswith("sqlite"):
    DATABASE_URL = settings.DATABASE_URL
else:
    # Convert sync PostgreSQL URL to async
    DATABASE_URL = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")

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
    """Initialize database tables"""
    print("DEBUG: Initializing database...")
    try:
        async with engine.begin() as conn:
            print("DEBUG: Connection opened, running metadata create_all...")
            await conn.run_sync(Base.metadata.create_all)
            print("DEBUG: Database initialization successful.")
    except Exception as e:
        print(f"DEBUG: Database initialization failed: {e}")
        raise
