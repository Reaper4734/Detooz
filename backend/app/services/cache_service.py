"""
Redis Cache Service
Async Redis wrapper with graceful degradation — all endpoints work without Redis.
"""
import json
import logging
from typing import Any, Optional

import redis.asyncio as aioredis

from app.config import settings

logger = logging.getLogger(__name__)


class CacheService:
    """Async Redis cache with automatic fallback to no-op when unavailable."""

    def __init__(self):
        self._redis: Optional[aioredis.Redis] = None
        self._available = False

    async def connect(self):
        """Connect to Redis. Logs warning and continues if unavailable."""
        try:
            self._redis = aioredis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=3,
                socket_timeout=2,
            )
            await self._redis.ping()
            self._available = True
            logger.info(f"Redis connected: {settings.REDIS_URL}")
        except Exception as e:
            self._available = False
            self._redis = None
            logger.warning(f"Redis unavailable ({e}). Running without cache.")

    async def disconnect(self):
        """Close the Redis connection pool."""
        if self._redis:
            await self._redis.aclose()
            self._redis = None
            self._available = False

    @property
    def is_available(self) -> bool:
        return self._available

    # ── Core Operations ──────────────────────────────────────────

    async def get(self, key: str) -> Optional[Any]:
        """Get a cached value (returns None on miss or if Redis is down)."""
        if not self._available:
            return None
        try:
            data = await self._redis.get(key)
            if data is not None:
                return json.loads(data)
        except Exception as e:
            logger.debug(f"Cache get failed for {key}: {e}")
        return None

    async def set(self, key: str, value: Any, ttl: int = 60):
        """Cache a value with TTL in seconds. Silently fails if Redis is down."""
        if not self._available:
            return
        try:
            await self._redis.set(key, json.dumps(value, default=str), ex=ttl)
        except Exception as e:
            logger.debug(f"Cache set failed for {key}: {e}")

    async def delete(self, key: str):
        """Delete a single key."""
        if not self._available:
            return
        try:
            await self._redis.delete(key)
        except Exception as e:
            logger.debug(f"Cache delete failed for {key}: {e}")

    async def delete_pattern(self, pattern: str):
        """Delete all keys matching a glob pattern (e.g. 'scan:history:42:*')."""
        if not self._available:
            return
        try:
            cursor = 0
            while True:
                cursor, keys = await self._redis.scan(cursor, match=pattern, count=100)
                if keys:
                    await self._redis.delete(*keys)
                if cursor == 0:
                    break
        except Exception as e:
            logger.debug(f"Cache delete_pattern failed for {pattern}: {e}")


# ── Singleton ────────────────────────────────────────────────────

_cache = CacheService()


def get_cache() -> CacheService:
    """Get the global cache instance (inject via FastAPI Depends or import directly)."""
    return _cache
