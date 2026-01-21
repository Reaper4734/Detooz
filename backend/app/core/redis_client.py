import redis
import logging
from app.config import settings

logger = logging.getLogger(__name__)

class RedisClient:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(RedisClient, cls).__new__(cls)
            cls._instance.client = None
            cls._instance.connect()
        return cls._instance
    
    def connect(self):
        try:
            self.client = redis.from_url(settings.REDIS_URL, decode_responses=True)
            # Test connection
            self.client.ping()
            logger.info("✅ Redis Connected Successfully")
        except redis.ConnectionError as e:
            logger.warning(f"⚠️ Redis Connection Failed: {e}. Falling back to No-Op/Memory.")
            self.client = None
        except Exception as e:
            logger.error(f"❌ Unexpected Redis Error: {e}")
            self.client = None
            
    def get(self, key: str):
        if not self.client:
            return None
        try:
            return self.client.get(key)
        except redis.RedisError as e:
            logger.error(f"Redis GET Error: {e}")
            return None
            
    def set(self, key: str, value: str):
        if not self.client:
            return False
        try:
            return self.client.set(key, value)
        except redis.RedisError as e:
            logger.error(f"Redis SET Error: {e}")
            return False

    def setex(self, key: str, time: int, value: str):
        """Set key with expiration (time in seconds)"""
        if not self.client:
            return False
        try:
            return self.client.setex(key, time, value)
        except redis.RedisError as e:
            logger.error(f"Redis SETEX Error: {e}")
            return False

    def delete(self, key: str):
        if not self.client:
            return False
        try:
            self.client.delete(key)
            return True
        except redis.RedisError as e:
            logger.error(f"Redis DELETE Error: {e}")
            return False
            
    def exists(self, key: str) -> bool:
        if not self.client:
            return False
        try:
            return bool(self.client.exists(key))
        except redis.RedisError:
            return False

# Global instance
redis_client = RedisClient()
