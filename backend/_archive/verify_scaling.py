
import asyncio
import sys
import os
from datetime import datetime, timedelta
import json
from sqlalchemy import select

# Add project root to path
sys.path.append(os.getcwd())

from app.db.database import async_session
from app.core.redis_client import redis_client
from app.services.archiver import archiver
from app.models import Scan, RiskLevel, PlatformType, User

async def verify_redis():
    print("\n🔹 [1/3] Verifying Redis...")
    if not redis_client.client:
        print("❌ Redis Client is None (Not connected)")
        return
    
    # Test Set
    key = "test:scaling:key"
    val = "hello_redis"
    success = redis_client.setex(key, 10, val)
    if not success:
        print("❌ Redis SET failed")
        return
        
    # Test Get
    retrieved = redis_client.get(key)
    if retrieved == val:
        print(f"✅ Redis SET/GET working. Value: {retrieved}")
    else:
        print(f"❌ Redis GET mismatch. Expected {val}, got {retrieved}")
        
    # Test Delete
    redis_client.delete(key)
    if not redis_client.get(key):
        print("✅ Redis DELETE working")


async def verify_archiver():
    print("\n🔹 [2/3] Verifying Archiver...")
    
    async with async_session() as db:
        # Create Dummy User to guarantee FK
        user = User(
            email="scaling_test@example.com",
            password_hash="dummy",
            first_name="Test",
            last_name="User"
        )
        db.add(user)
        try:
            await db.commit()
            await db.refresh(user)
        except Exception:
            await db.rollback()
            # Try getting if exists
            res = await db.execute(select(User).where(User.email == "scaling_test@example.com"))
            user = res.scalar_one()
            
        uid = user.id
        print(f"   Using Test User ID: {uid}")
        
        old_date = datetime.utcnow() - timedelta(days=200)
        
        scan = Scan(
            user_id=uid,
            sender="+910000000000",
            message="Old scam message to archive",
            risk_level=RiskLevel.HIGH,
            platform=PlatformType.SMS,
            created_at=old_date
        )
        db.add(scan)
        await db.commit()
        await db.refresh(scan)
        sid = scan.id
        print(f"   Created dummy old scan ID: {sid} (Date: {old_date.date()})")
        
        # Run Archiver
        print("   Running Archiver (cutoff: 180 days)...")
        stats = await archiver.archive_old_scans(db, days_to_keep=180)
        print(f"   Archiver Output: {stats}")
        
        # Verify File
        filename = stats.get("filename")
        if filename and os.path.exists(filename):
            print(f"✅ Archive file created: {filename}")
            # Clean up file
            # os.remove(filename) 
        else:
            print(f"❌ Archive file NOT found: {filename}")
            
        # Verify DB Deletion
        check = await db.get(Scan, sid)
        if hasattr(check, 'id'):  # SQLAlchemy might return object with session state
             # Re-query
             res = await db.execute(select(Scan).where(Scan.id == sid))
             check = res.scalar_one_or_none()
        
        if not check:
            print("✅ DB Record deleted successfully")
        else:
            print("❌ DB Record still exists!")

async def main():
    print("🚀 Starting Scaling Verification (Redis + Archiver)")
    try:
        await verify_redis()
        # await verify_archiver() # Commenting out to avoid needing dummy user logic complexity unless confirmed
        # Actually let's include imports needed for verify_archiver and run it
        await verify_archiver()
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(main())
