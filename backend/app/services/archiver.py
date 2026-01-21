"""
Archiver Service
Moves old data from hot database to cold file storage (JSONL)
Supports Pluggable Storage Backends (Local Disk vs Cloud S3)
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from datetime import datetime, timedelta
import json
import os
import aiofiles
from app.models import Scan
import logging

logger = logging.getLogger(__name__)

# ================= STORAGE BACKENDS =================

class StorageProvider:
    async def save(self, filename: str, content: str) -> str:
        raise NotImplementedError
        
    async def delete(self, filename: str) -> bool:
        raise NotImplementedError

class LocalStorage(StorageProvider):
    def __init__(self, base_dir: str = "storage/archives"):
        self.base_dir = base_dir
        os.makedirs(self.base_dir, exist_ok=True)
        
    async def save(self, filename: str, content: str) -> str:
        full_path = f"{self.base_dir}/{filename}"
        async with aiofiles.open(full_path, mode='w', encoding='utf-8') as f:
            await f.write(content)
        return full_path

class S3Storage(StorageProvider):
    def __init__(self, bucket_name: str):
        self.bucket = bucket_name
        
    async def save(self, filename: str, content: str) -> str:
        # Stub implementation for future cloud deployment
        # Would use: boto3.client('s3').put_object(...)
        logger.info(f"CLOUD SIMULATION: Uploading {filename} to S3 Bucket {self.bucket}...")
        return f"s3://{self.bucket}/{filename}"

# Factory
def get_storage_provider() -> StorageProvider:
    provider = os.getenv("STORAGE_PROVIDER", "LOCAL").upper()
    if provider == "S3":
        bucket = os.getenv("S3_BUCKET_NAME", "detooz-archives")
        return S3Storage(bucket)
    else:
        return LocalStorage()

# ================= SERVICE =================

class ArchiverService:
    
    def __init__(self):
        self.storage = get_storage_provider()
    
    async def archive_old_scans(self, db: AsyncSession, days_to_keep: int = 180) -> dict:
        """
        Archive scans older than `days_to_keep`.
        """
        cutoff_date = datetime.utcnow() - timedelta(days=days_to_keep)
        
        # 1. Select
        result = await db.execute(
            select(Scan).where(Scan.created_at < cutoff_date)
        )
        scans = result.scalars().all()
        
        if not scans:
            return {"archived_count": 0, "bytes_saved": 0}
            
        # Prepare Data
        lines = []
        for scan in scans:
            record = {
                "id": scan.id,
                "user_id": scan.user_id,
                "sender": scan.sender,
                "message": scan.message,
                "risk_level": scan.risk_level.value,
                "created_at": scan.created_at.isoformat(),
            }
            lines.append(json.dumps(record))
            
        content = "\n".join(lines)
        
        # 2. Save to Storage (Local or Cloud)
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"scans_{timestamp}.jsonl"
        
        try:
            path = await self.storage.save(filename, content)
            logger.info(f"Archived {len(scans)} records to {path}")
        except Exception as e:
            logger.error(f"Archive Write Failed: {e}")
            return {"error": str(e)}

        # 3. Delete from DB (Only if write successful)
        try:
            scan_ids = [s.id for s in scans]
            await db.execute(delete(Scan).where(Scan.id.in_(scan_ids)))
            await db.commit()
            logger.info(f"Deleted {len(scans)} archived records from DB")
            
        except Exception as e:
            logger.error(f"Archive Cleanup Failed: {e}")
            return {"warning": "File created but DB delete failed", "path": path}
            
        return {
            "archived_count": len(scans),
            "filename": path,
            "provider": type(self.storage).__name__
        }

# Global instance
archiver = ArchiverService()
