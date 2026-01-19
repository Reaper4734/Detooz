import asyncio
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
# Force settings update before other imports if possible, or just hack the logging after
import logging

# Configure basic logging to stderr to separate from stdout
logging.basicConfig(stream=sys.stderr, level=logging.WARNING)
logging.getLogger('sqlalchemy.engine').setLevel(logging.WARNING)

from sqlalchemy import select
from app.db.database import async_session
from app.models import Guardian

async def list_guardians():
    print("DEBUG: Script started", flush=True)
    try:
        print("DEBUG: creating session", flush=True)
        async with async_session() as db:
            print("DEBUG: Session created, executing select", flush=True)
            result = await db.execute(select(Guardian))
            print("DEBUG: Query executed", flush=True)
            guardians = result.scalars().all()
            
            print(f"RESULT: Found {len(guardians)} guardians:", flush=True)
            for g in guardians:
                print(f"GUARDIAN: ID: {g.id}, Name: {g.name}, Telegram: {g.telegram_chat_id}", flush=True)
    except Exception as e:
        print(f"ERROR: {e}", flush=True)
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(list_guardians())
