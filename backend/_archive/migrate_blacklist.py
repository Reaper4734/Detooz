"""
Database Migration Script
Adds LLM training data columns to blacklist table
Run this script to update existing database
"""
import asyncio
from sqlalchemy import text
from app.db import engine

async def migrate():
    """Add new columns to blacklist table""" 
    
    migrations = [
        # Add LLM training data columns (SQLite doesn't support IF NOT EXISTS)
        ("full_message", "ALTER TABLE blacklist ADD COLUMN full_message TEXT"),
        ("ai_reasoning", "ALTER TABLE blacklist ADD COLUMN ai_reasoning TEXT"),
        ("scam_type", "ALTER TABLE blacklist ADD COLUMN scam_type VARCHAR(100)"),
        ("confidence_score", "ALTER TABLE blacklist ADD COLUMN confidence_score FLOAT"),
        ("detection_method", "ALTER TABLE blacklist ADD COLUMN detection_method VARCHAR(20) DEFAULT 'user_report'"),
        ("language", "ALTER TABLE blacklist ADD COLUMN language VARCHAR(10) DEFAULT 'en'"),
        ("features_detected", "ALTER TABLE blacklist ADD COLUMN features_detected TEXT"),
    ]
    
    async with engine.begin() as conn:
        for column_name, migration in migrations:
            print(f"Adding column: {column_name}")
            try:
                await conn.execute(text(migration))
                print(f"✓ Added {column_name}")
            except Exception as e:
                if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                    print(f"⚠ Column {column_name} already exists, skipping")
                else:
                    print(f"✗ Error: {e}")
                    raise
    
    print("\n✅ Migration completed!")


if __name__ == "__main__":
    print("Starting blacklist table migration...")
    print("Adding LLM training data columns...\n")
    asyncio.run(migrate())
