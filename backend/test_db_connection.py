import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy import text
from app.config import settings

async def test_db():
    print(f"Connecting to DB: {settings.DATABASE_URL}")
    try:
        engine = create_async_engine(settings.DATABASE_URL, echo=True)
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT email FROM users"))
            users = result.fetchall()
            print("\n✅ Database Connected Successfully!")
            print(f"Found {len(users)} users:")
            for u in users:
                print(f" - {u[0]}")
    except Exception as e:
        print(f"\n❌ Database Connection Failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_db())
