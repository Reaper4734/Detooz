"""
Privacy Compliance Migration Script
Adds consent fields to Users table and creates ConsentLogs table
"""
import asyncio
from sqlalchemy import text
from app.db import engine

async def migrate():
    """Add privacy columns and tables"""
    
    user_updates = [
        ("consent_training_data", "ALTER TABLE users ADD COLUMN consent_training_data BOOLEAN DEFAULT 0"),
        ("consent_analytics", "ALTER TABLE users ADD COLUMN consent_analytics BOOLEAN DEFAULT 0"),
        ("consent_version", "ALTER TABLE users ADD COLUMN consent_version VARCHAR(10) DEFAULT '1.0'"),
        ("consent_given_at", "ALTER TABLE users ADD COLUMN consent_given_at TIMESTAMP"),
        ("consent_ip_address", "ALTER TABLE users ADD COLUMN consent_ip_address VARCHAR(45)"),
        ("data_retention_days", "ALTER TABLE users ADD COLUMN data_retention_days INTEGER DEFAULT 365"),
        ("anonymize_data", "ALTER TABLE users ADD COLUMN anonymize_data BOOLEAN DEFAULT 1"),
    ]
    
    settings_updates = [
        ("share_scam_patterns", "ALTER TABLE user_settings ADD COLUMN share_scam_patterns BOOLEAN DEFAULT 0"),
        ("allow_research_use", "ALTER TABLE user_settings ADD COLUMN allow_research_use BOOLEAN DEFAULT 0"),
        ("data_export_requested", "ALTER TABLE user_settings ADD COLUMN data_export_requested BOOLEAN DEFAULT 0"),
    ]
    
    create_consent_logs = """
    CREATE TABLE IF NOT EXISTS consent_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        consent_type VARCHAR(50),
        consent_given BOOLEAN,
        consent_version VARCHAR(10),
        ip_address VARCHAR(45),
        user_agent TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )
    """
    
    async with engine.begin() as conn:
        print("--- Migrating Users Table ---")
        for column_name, migration in user_updates:
            try:
                await conn.execute(text(migration))
                print(f"✓ Added {column_name}")
            except Exception as e:
                if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                    print(f"⚠ Column {column_name} already exists")
                else:
                    print(f"✗ Error adding {column_name}: {e}")
        
        print("\n--- Migrating UserSettings Table ---")
        for column_name, migration in settings_updates:
            try:
                await conn.execute(text(migration))
                print(f"✓ Added {column_name}")
            except Exception as e:
                if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                    print(f"⚠ Column {column_name} already exists")
                else:
                    print(f"✗ Error adding {column_name}: {e}")
                    
        print("\n--- Creating Consent Logs Table ---")
        try:
            await conn.execute(text(create_consent_logs))
            print("✓ Created consent_logs table")
        except Exception as e:
            print(f"✗ Error creating table: {e}")
    
    print("\n✅ Privacy migration completed!")

if __name__ == "__main__":
    print("Starting privacy compliance migration...\n")
    asyncio.run(migrate())
