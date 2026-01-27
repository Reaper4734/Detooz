import redis
import logging
import time
from typing import Optional, Dict, Any
from app.config import settings

logger = logging.getLogger(__name__)

class InMemoryCache:
    """Simple in-memory cache fallback when Redis is unavailable"""
    def __init__(self):
        self._cache: Dict[str, Dict[str, Any]] = {}
    
    def get(self, key: str) -> Optional[str]:
        self._cleanup_expired()
        item = self._cache.get(key)
        if item and item['expires_at'] > time.time():
            return item['value']
        return None
    
    def set(self, key: str, value: str) -> bool:
        self._cache[key] = {'value': value, 'expires_at': float('inf')}
        return True
    
    def setex(self, key: str, ttl: int, value: str) -> bool:
        self._cache[key] = {'value': value, 'expires_at': time.time() + ttl}
        return True
    
    def delete(self, key: str) -> bool:
        self._cache.pop(key, None)
        return True
    
    def exists(self, key: str) -> bool:
        self._cleanup_expired()
        return key in self._cache
    
    def _cleanup_expired(self):
        now = time.time()
        expired_keys = [k for k, v in self._cache.items() if v['expires_at'] <= now]
        for k in expired_keys:
            del self._cache[k]

class RedisClient:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(RedisClient, cls).__new__(cls)
            cls._instance.client = None
            cls._instance.fallback = InMemoryCache()
            cls._instance.using_fallback = False
            cls._instance.connect()
        return cls._instance
    
    def connect(self):
        try:
            self.client = redis.from_url(
                settings.REDIS_URL, 
                decode_responses=True,
                socket_timeout=2,
                socket_connect_timeout=2
            )
            # Test connection
            self.client.ping()
            logger.info("✅ Redis Connected Successfully")
            self.using_fallback = False
        except redis.ConnectionError as e:
            logger.warning(f"⚠️ Redis Connection Failed: {e}. Using in-memory fallback.")
            self.client = None
            self.using_fallback = True
        except Exception as e:
            logger.error(f"❌ Unexpected Redis Error: {e}. Using in-memory fallback.")
            self.client = None
            self.using_fallback = True
            
    def get(self, key: str):
        if self.using_fallback or not self.client:
            return self.fallback.get(key)
        try:
            return self.client.get(key)
        except redis.RedisError as e:
            logger.error(f"Redis GET Error: {e}")
            return self.fallback.get(key)
            
    def set(self, key: str, value: str):
        if self.using_fallback or not self.client:
            return self.fallback.set(key, value)
        try:
            return self.client.set(key, value)
        except redis.RedisError as e:
            logger.error(f"Redis SET Error: {e}")
            return self.fallback.set(key, value)

    def setex(self, key: str, time_seconds: int, value: str):
        """Set key with expiration (time in seconds)"""
        if self.using_fallback or not self.client:
            return self.fallback.setex(key, time_seconds, value)
        try:
            return self.client.setex(key, time_seconds, value)
        except redis.RedisError as e:
            logger.error(f"Redis SETEX Error: {e}")
            return self.fallback.setex(key, time_seconds, value)

    def delete(self, key: str):
        if self.using_fallback or not self.client:
            return self.fallback.delete(key)
        try:
            self.client.delete(key)
            return True
        except redis.RedisError as e:
            logger.error(f"Redis DELETE Error: {e}")
            return self.fallback.delete(key)
            
    def exists(self, key: str) -> bool:
        if self.using_fallback or not self.client:
            return self.fallback.exists(key)
        try:
            return bool(self.client.exists(key))
        except redis.RedisError:
            return self.fallback.exists(key)

# Global instance
redis_client = RedisClient()

