"""
Education Router
API endpoints for Learn tab content
Uses live RSS feeds with caching and URL-only bookmarks
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel
import os

from app.db.database import get_db
from app.models.models import UserBookmark, DetoozExclusive, ArticleCategory, User
from app.routers.auth import get_current_user, get_current_user_optional
from app.services.feed_aggregator import get_cached_feeds, fetch_all_feeds
from app.services.cache_service import get_cache

router = APIRouter(prefix="/education", tags=["Education"])


# ============================================
# Schemas
# ============================================

class ArticleResponse(BaseModel):
    """Response model for feed articles"""
    url: str  # Unique identifier (primary key for bookmarks)
    title: str
    summary: Optional[str]
    image_url: Optional[str]
    source: str
    category: str
    read_time_mins: int
    published_at: Optional[datetime]
    is_exclusive: bool = False  # True if Detooz Exclusive
    is_bookmarked: bool = False

    class Config:
        from_attributes = True


class ExclusiveResponse(BaseModel):
    """Response model for Detooz Exclusive content"""
    id: int
    title: str
    content: str
    image_url: Optional[str]
    category: str
    read_time_mins: int
    created_at: datetime

    class Config:
        from_attributes = True


class FeedResponse(BaseModel):
    """Combined feed response with RSS and Exclusive content"""
    articles: List[ArticleResponse]
    total: int
    exclusive: List[ExclusiveResponse]


class BookmarkRequest(BaseModel):
    """Request to add a bookmark (URL-based)"""
    url: str
    title: str
    source: str
    image_url: Optional[str] = None
    is_exclusive: bool = False


class BookmarkResponse(BaseModel):
    """Response for bookmark list"""
    url: str
    title: str
    source: str
    image_url: Optional[str]
    is_exclusive: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================
# Feed Endpoints (Live RSS)
# ============================================

@router.get("/feed", response_model=FeedResponse)
async def get_feed(
    category: Optional[str] = Query(None, description="Filter: all, alert, tip, news"),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional)
):
    """
    Get educational feed articles (LIVE from RSS with caching).
    Returns both RSS feed articles and Detooz Exclusive content.
    Works without auth, but bookmarked status requires login.
    """
    # Get user's bookmarked URLs (if logged in)
    bookmarked_urls = set()
    if current_user:
        bookmark_result = await db.execute(
            select(UserBookmark.url).where(UserBookmark.user_id == current_user.id)
        )
        bookmarked_urls = {row[0] for row in bookmark_result.fetchall() if row[0]}
    
    # Get live RSS feeds (cached for 5 min)
    articles, total = await get_cached_feeds(offset=offset, limit=limit, category=category)
    
    # Format response
    articles_response = [
        ArticleResponse(
            url=a.get('url', ''),
            title=a.get('title', ''),
            summary=a.get('summary', ''),
            image_url=a.get('image_url'),
            source=a.get('source', 'Unknown'),
            category=a.get('category', 'news'),
            read_time_mins=a.get('read_time_mins', 3),
            published_at=a.get('published_at'),
            is_exclusive=False,
            is_bookmarked=a.get('url', '') in bookmarked_urls
        )
        for a in articles
    ]
    
    # Get Detooz Exclusive content
    exclusive_query = select(DetoozExclusive).where(
        DetoozExclusive.is_active == True
    ).order_by(desc(DetoozExclusive.created_at)).limit(5)
    
    exclusive_result = await db.execute(exclusive_query)
    exclusive_articles = exclusive_result.scalars().all()
    
    exclusive_response = [
        ExclusiveResponse(
            id=e.id,
            title=e.title,
            content=e.content,
            image_url=e.image_url,
            category=e.category.value,
            read_time_mins=e.read_time_mins,
            created_at=e.created_at
        )
        for e in exclusive_articles
    ]
    
    return FeedResponse(
        articles=articles_response,
        total=total,
        exclusive=exclusive_response
    )


# ============================================
# Bookmark Endpoints (URL-based)
# ============================================

@router.get("/bookmarks")
async def get_bookmarks(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get user's bookmarked articles (URL-based, never expires)"""
    result = await db.execute(
        select(UserBookmark)
        .where(UserBookmark.user_id == current_user.id)
        .order_by(desc(UserBookmark.created_at))
    )
    bookmarks = result.scalars().all()
    
    return {
        "bookmarks": [
            BookmarkResponse(
                url=b.url,
                title=b.title,
                source=b.source or "Unknown",
                image_url=b.image_url,
                is_exclusive=b.is_exclusive,
                created_at=b.created_at
            )
            for b in bookmarks
        ],
        "total": len(bookmarks)
    }


@router.post("/bookmark")
async def add_bookmark(
    request: BookmarkRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Bookmark an article (URL-based)"""
    # Check if already bookmarked
    existing = await db.execute(
        select(UserBookmark).where(
            UserBookmark.user_id == current_user.id,
            UserBookmark.url == request.url
        )
    )
    
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Already bookmarked")
    
    # Create bookmark with URL
    bookmark = UserBookmark(
        user_id=current_user.id,
        url=request.url,
        title=request.title,
        source=request.source,
        image_url=request.image_url,
        is_exclusive=request.is_exclusive
    )
    db.add(bookmark)
    await db.commit()
    
    return {"success": True, "message": "Article bookmarked"}


@router.delete("/bookmark")
async def remove_bookmark(
    url: str = Query(..., description="URL of the article to unbookmark"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Remove a bookmark by URL"""
    result = await db.execute(
        select(UserBookmark).where(
            UserBookmark.user_id == current_user.id,
            UserBookmark.url == url
        )
    )
    
    bookmark = result.scalar_one_or_none()
    if not bookmark:
        raise HTTPException(status_code=404, detail="Bookmark not found")
    
    await db.delete(bookmark)
    await db.commit()
    
    return {"success": True, "message": "Bookmark removed"}


# ============================================
# Detooz Exclusive Content
# ============================================

@router.post("/generate-exclusive")
async def generate_exclusive_content(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Generate Detooz Exclusive educational content using Groq AI.
    Admin/scheduled endpoint.
    """
    from app.services.content_curator import generate_exclusive_content as generate_content
    
    groq_api_key = os.environ.get("GROQ_API_KEY")
    if not groq_api_key:
        raise HTTPException(status_code=500, detail="Groq API key not configured")
    
    exclusive = await generate_content(db, groq_api_key)
    
    if not exclusive:
        raise HTTPException(status_code=500, detail="Failed to generate content")
    
    # Invalidate exclusive content cache
    cache = get_cache()
    await cache.delete_pattern("edu:exclusive:*")
    
    return {
        "success": True,
        "exclusive": {
            "id": exclusive.id,
            "title": exclusive.title,
            "content": exclusive.content,
            "created_at": exclusive.created_at.isoformat()
        }
    }


@router.get("/exclusive")
async def get_exclusive_content(
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get Detooz Exclusive content list"""
    
    # Check cache first
    cache = get_cache()
    cache_key = f"edu:exclusive:{limit}"
    cached = await cache.get(cache_key)
    if cached is not None:
        return cached
    
    result = await db.execute(
        select(DetoozExclusive)
        .where(DetoozExclusive.is_active == True)
        .order_by(desc(DetoozExclusive.created_at))
        .limit(limit)
    )
    articles = result.scalars().all()
    
    response = {
        "exclusive": [
            {
                "id": e.id, "title": e.title, "content": e.content,
                "image_url": e.image_url, "category": e.category.value,
                "read_time_mins": e.read_time_mins,
                "created_at": str(e.created_at),
            }
            for e in articles
        ],
        "total": len(articles)
    }
    
    # Cache for 10 minutes
    await cache.set(cache_key, response, ttl=600)
    
    return response


# ============================================
# Legacy/Debug Endpoints
# ============================================

@router.post("/sync-feeds")
async def sync_feeds():
    """
    Force refresh RSS feed cache (debug endpoint).
    Not needed in live architecture - feeds are fetched on-demand.
    """
    articles = await fetch_all_feeds(force_refresh=True)
    return {"success": True, "articles_cached": len(articles)}
