import sqlite3
import os

DB_PATH = "../detooz.db"

def migrate_db():
    if not os.path.exists(DB_PATH):
        print("Database not found, nothing to migrate.")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Check if fcm_token column exists in users table
    cursor.execute("PRAGMA table_info(users)")
    columns = [info[1] for info in cursor.fetchall()]
    
    if "fcm_token" not in columns:
        print("Migrating: Adding fcm_token column to users table...")
        try:
            cursor.execute("ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255)")
            conn.commit()
            print("Migration successful! fcm_token column added.")
        except Exception as e:
            print(f"Migration failed: {e}")
    else:
        print("No migration needed: fcm_token column already exists.")
        
    conn.close()

if __name__ == "__main__":
    migrate_db()
