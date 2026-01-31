"""
Education Router
API endpoints for Learn tab content
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, desc
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel

from app.db.database import get_db
from app.models.models import (
    FeedArticle, CuratedArticle, UserBookmark, 
    ArticleCategory, User
)
from app.routers.auth import get_current_user

router = APIRouter(prefix="/education", tags=["Education"])


# ============================================
# Schemas
# ============================================

class ArticleResponse(BaseModel):
    id: int
    title: str
    summary: Optional[str]
    image_url: Optional[str]
    source: str
    category: str
    read_time_mins: int
    url: Optional[str]
    published_at: Optional[datetime]
    is_curated: bool = False
    is_bookmarked: bool = False

    class Config:
        from_attributes = True


class FeedResponse(BaseModel):
    articles: List[ArticleResponse]
    total: int
    curated: List[ArticleResponse]


class BookmarkRequest(BaseModel):
    article_id: int
    is_curated: bool = False


# ============================================
# Endpoints
# ============================================

@router.get("/feed", response_model=FeedResponse)
async def get_feed(
    category: Optional[str] = Query(None, description="Filter: all, alert, tip, news"),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get educational feed articles.
    Returns both RSS feed articles and curated Detooz content.
    """
    # Get user's bookmarked article IDs
    bookmark_result = await db.execute(
        select(UserBookmark).where(UserBookmark.user_id == current_user.id)
    )
    bookmarks = bookmark_result.scalars().all()
    bookmarked_feed_ids = {b.feed_article_id for b in bookmarks if b.feed_article_id}
    bookmarked_curated_ids = {b.curated_article_id for b in bookmarks if b.curated_article_id}
    
    # Build category filter
    category_filter = None
    if category and category != "all":
        category_map = {
            "alert": ArticleCategory.ALERT,
            "tip": ArticleCategory.TIP,
            "news": ArticleCategory.NEWS
        }
        if category in category_map:
            category_filter = category_map[category]
    
    # Get feed articles
    feed_query = select(FeedArticle).where(FeedArticle.is_active == True)
    if category_filter:
        feed_query = feed_query.where(FeedArticle.category == category_filter)
    feed_query = feed_query.order_by(desc(FeedArticle.published_at)).offset(offset).limit(limit)
    
    feed_result = await db.execute(feed_query)
    feed_articles = feed_result.scalars().all()
    
    # Get total count
    count_query = select(FeedArticle).where(FeedArticle.is_active == True)
    if category_filter:
        count_query = count_query.where(FeedArticle.category == category_filter)
    count_result = await db.execute(count_query)
    total = len(count_result.scalars().all())
    
    # Get curated articles
    curated_query = select(CuratedArticle).where(CuratedArticle.is_active == True)
    if category_filter:
        curated_query = curated_query.where(CuratedArticle.category == category_filter)
    curated_query = curated_query.order_by(desc(CuratedArticle.is_featured), desc(CuratedArticle.created_at)).limit(10)
    
    curated_result = await db.execute(curated_query)
    curated_articles = curated_result.scalars().all()
    
    # Format response
    articles_response = [
        ArticleResponse(
            id=a.id,
            title=a.title,
            summary=a.summary,
            image_url=a.image_url,
            source=a.source,
            category=a.category.value,
            read_time_mins=a.read_time_mins,
            url=a.url,
            published_at=a.published_at,
            is_curated=False,
            is_bookmarked=a.id in bookmarked_feed_ids
        )
        for a in feed_articles
    ]
    
    curated_response = [
        ArticleResponse(
            id=a.id,
            title=a.title,
            summary=a.summary,
            image_url=a.image_url,
            source="Detooz",
            category=a.category.value,
            read_time_mins=a.read_time_mins,
            url=None,
            published_at=a.created_at,
            is_curated=True,
            is_bookmarked=a.id in bookmarked_curated_ids
        )
        for a in curated_articles
    ]
    
    return FeedResponse(
        articles=articles_response,
        total=total,
        curated=curated_response
    )


@router.get("/bookmarks")
async def get_bookmarks(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get user's bookmarked articles"""
    result = await db.execute(
        select(UserBookmark)
        .where(UserBookmark.user_id == current_user.id)
        .order_by(desc(UserBookmark.created_at))
    )
    bookmarks = result.scalars().all()
    
    articles = []
    for bookmark in bookmarks:
        if bookmark.feed_article:
            a = bookmark.feed_article
            articles.append(ArticleResponse(
                id=a.id,
                title=a.title,
                summary=a.summary,
                image_url=a.image_url,
                source=a.source,
                category=a.category.value,
                read_time_mins=a.read_time_mins,
                url=a.url,
                published_at=a.published_at,
                is_curated=False,
                is_bookmarked=True
            ))
        elif bookmark.curated_article:
            a = bookmark.curated_article
            articles.append(ArticleResponse(
                id=a.id,
                title=a.title,
                summary=a.summary,
                image_url=a.image_url,
                source="Detooz",
                category=a.category.value,
                read_time_mins=a.read_time_mins,
                url=None,
                published_at=a.created_at,
                is_curated=True,
                is_bookmarked=True
            ))
    
    return {"bookmarks": articles, "total": len(articles)}


@router.post("/bookmark")
async def add_bookmark(
    request: BookmarkRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Bookmark an article"""
    # Check if already bookmarked
    if request.is_curated:
        existing = await db.execute(
            select(UserBookmark).where(
                UserBookmark.user_id == current_user.id,
                UserBookmark.curated_article_id == request.article_id
            )
        )
    else:
        existing = await db.execute(
            select(UserBookmark).where(
                UserBookmark.user_id == current_user.id,
                UserBookmark.feed_article_id == request.article_id
            )
        )
    
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Already bookmarked")
    
    # Create bookmark
    bookmark = UserBookmark(
        user_id=current_user.id,
        feed_article_id=None if request.is_curated else request.article_id,
        curated_article_id=request.article_id if request.is_curated else None
    )
    db.add(bookmark)
    await db.commit()
    
    return {"success": True, "message": "Article bookmarked"}


@router.delete("/bookmark/{article_id}")
async def remove_bookmark(
    article_id: int,
    is_curated: bool = Query(False),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Remove a bookmark"""
    if is_curated:
        result = await db.execute(
            select(UserBookmark).where(
                UserBookmark.user_id == current_user.id,
                UserBookmark.curated_article_id == article_id
            )
        )
    else:
        result = await db.execute(
            select(UserBookmark).where(
                UserBookmark.user_id == current_user.id,
                UserBookmark.feed_article_id == article_id
            )
        )
    
    bookmark = result.scalar_one_or_none()
    if not bookmark:
        raise HTTPException(status_code=404, detail="Bookmark not found")
    
    await db.delete(bookmark)
    await db.commit()
    
    return {"success": True, "message": "Bookmark removed"}


@router.post("/sync-feeds")
async def sync_feeds(
    db: AsyncSession = Depends(get_db)
):
    """
    Manually trigger feed sync (admin/debug).
    In production, this runs on a scheduler.
    """
    from app.services.feed_aggregator import sync_feeds_to_db
    
    added = await sync_feeds_to_db(db)
    return {"success": True, "articles_added": added}

