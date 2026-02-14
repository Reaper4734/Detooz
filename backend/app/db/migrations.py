"""
Database Migration Utilities
Handles automatic schema migration for SQLite databases
This prevents the need to delete the database when models change
"""
import sqlite3
import logging
from typing import Set
from sqlalchemy import inspect

logger = logging.getLogger(__name__)


def get_existing_columns(db_path: str, table_name: str) -> Set[str]:
    """Get existing column names for a table"""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.execute(f"PRAGMA table_info({table_name})")
        columns = {row[1] for row in cursor.fetchall()}
        conn.close()
        return columns
    except Exception as e:
        logger.error(f"Error getting columns: {e}")
        return set()


def add_column_if_missing(db_path: str, table_name: str, column_name: str, column_type: str, default: str = None):
    """Add a column to table if it doesn't exist"""
    existing = get_existing_columns(db_path, table_name)
    
    if column_name in existing:
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        
        # Build ALTER TABLE statement
        sql = f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}"
        if default is not None:
            sql += f" DEFAULT {default}"
        
        conn.execute(sql)
        conn.commit()
        conn.close()
        
        logger.info(f"Added column {table_name}.{column_name}")
        return True
    except Exception as e:
        logger.error(f"Error adding column {column_name}: {e}")
        return False


def migrate_user_table(db_path: str):
    """Apply all migrations for the users table"""
    migrations = [
        # (column_name, sqlite_type, default_value)
        ("email_verified", "BOOLEAN", "0"),
        ("phone_verified", "BOOLEAN", "0"),
        ("firebase_uid", "VARCHAR(128)", "NULL"),
        ("google_uid", "VARCHAR(128)", "NULL"),
        ("verification_grace_period_end", "DATETIME", "NULL"),
        ("profile_picture", "TEXT", "NULL"),
    ]
    
    for column_name, column_type, default in migrations:
        add_column_if_missing(db_path, "users", column_name, column_type, default)


def run_migrations(db_path: str):
    """Run all pending migrations"""
    logger.info(f"Running migrations on {db_path}")
    
    # Check if database exists
    import os
    if not os.path.exists(db_path):
        logger.info("No existing database, skipping migrations")
        return
    
    # Run migrations for each table
    migrate_user_table(db_path)
    
    logger.info("Migrations complete")
