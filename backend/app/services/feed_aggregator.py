"""
Feed Aggregator Service
Fetches and processes RSS feeds from educational sources
With in-memory caching for live feed architecture
"""
import asyncio
import re
from datetime import datetime, timedelta
from typing import List, Optional, Tuple
import logging

logger = logging.getLogger(__name__)

# In-memory cache for RSS feeds
_feed_cache: List[dict] = []
_cache_timestamp: Optional[datetime] = None
CACHE_TTL_MINUTES = 5  # Cache expires after 5 minutes

# RSS Feed sources - Scam education, cybersecurity, and online safety
FEED_SOURCES = [
    {
        "name": "Quick Heal",
        "url": "https://blogs.quickheal.com/feed/",
        "default_category": "tip"
    },
    {
        "name": "GBHackers",
        "url": "https://gbhackers.com/feed/",
        "default_category": "news"
    },
    {
        "name": "The Hacker News",
        "url": "https://feeds.feedburner.com/TheHackersNews",
        "default_category": "news"
    },
    {
        "name": "Krebs on Security",
        "url": "https://krebsonsecurity.com/feed/",
        "default_category": "news"
    },
    {
        "name": "Naked Security",
        "url": "https://nakedsecurity.sophos.com/feed/",
        "default_category": "tip"
    },
    {
        "name": "Dark Reading",
        "url": "https://www.darkreading.com/rss.xml",
        "default_category": "news"
    },
    {
        "name": "Security Week",
        "url": "https://www.securityweek.com/feed/",
        "default_category": "news"
    },
    {
        "name": "Bleeping Computer",
        "url": "https://www.bleepingcomputer.com/feed/",
        "default_category": "alert"
    },
    {
        "name": "CERT-In",
        "url": "https://www.cert-in.org.in/rss/rss-feed.php",
        "default_category": "alert"
    },
    {
        "name": "Cyber Security News",
        "url": "https://cybersecuritynews.com/feed/",
        "default_category": "news"
    }
]

# Keywords for categorization
ALERT_KEYWORDS = ["alert", "warning", "scam", "fraud", "attack", "breach", "vulnerability", "urgent"]
TIP_KEYWORDS = ["how to", "tips", "guide", "protect", "secure", "safety", "best practice"]


def estimate_read_time(text: str) -> int:
    """Estimate read time in minutes (average 200 words per minute)"""
    if not text:
        return 2
    word_count = len(text.split())
    minutes = max(1, round(word_count / 200))
    return min(minutes, 15)  # Cap at 15 minutes


def categorize_article(title: str, summary: str) -> str:
    """Categorize article based on keywords"""
    text = f"{title} {summary}".lower()
    
    # Check for alert keywords first
    for keyword in ALERT_KEYWORDS:
        if keyword in text:
            return "alert"
    
    # Check for tip keywords
    for keyword in TIP_KEYWORDS:
        if keyword in text:
            return "tip"
    
    return "news"


def clean_html(html_text: str) -> str:
    """Remove HTML tags from text"""
    if not html_text:
        return ""
    # Remove HTML tags
    clean = re.sub(r'<[^>]+>', '', html_text)
    # Decode HTML entities
    clean = clean.replace('&nbsp;', ' ')
    clean = clean.replace('&amp;', '&')
    clean = clean.replace('&lt;', '<')
    clean = clean.replace('&gt;', '>')
    clean = clean.replace('&quot;', '"')
    # Remove extra whitespace
    clean = ' '.join(clean.split())
    return clean.strip()


def extract_image_url(entry: dict) -> Optional[str]:
    """Extract image URL from feed entry"""
    # Try media_content
    if hasattr(entry, 'media_content') and entry.media_content:
        for media in entry.media_content:
            if 'url' in media:
                return media['url']
    
    # Try media_thumbnail
    if hasattr(entry, 'media_thumbnail') and entry.media_thumbnail:
        for thumb in entry.media_thumbnail:
            if 'url' in thumb:
                return thumb['url']
    
    # Try enclosures
    if hasattr(entry, 'enclosures') and entry.enclosures:
        for enc in entry.enclosures:
            if enc.get('type', '').startswith('image'):
                return enc.get('url')
    
    # Try to find img in content
    content = ""
    if hasattr(entry, 'content') and entry.content:
        content = entry.content[0].get('value', '')
    elif hasattr(entry, 'summary'):
        content = entry.summary or ""
    
    img_match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', content)
    if img_match:
        return img_match.group(1)
    
    return None


async def fetch_feed(source: dict) -> List[dict]:
    """Fetch and parse a single RSS feed"""
    try:
        import feedparser
        import aiohttp
        
        logger.info(f"Fetching feed from {source['name']}: {source['url']}")
        
        # User-Agent header to avoid 403 blocks
        headers = {
            'User-Agent': 'Mozilla/5.0 (compatible; DetoozBot/1.0; +https://detooz.app)'
        }
        
        # Use aiohttp for non-blocking fetch
        async with aiohttp.ClientSession() as session:
            async with session.get(source['url'], timeout=15, headers=headers) as response:
                if response.status != 200:
                    logger.warning(f"Failed to fetch {source['name']}: {response.status}")
                    return []
                content = await response.text()
        
        # Parse content in executor (CPU bound)
        loop = asyncio.get_running_loop()
        feed = await loop.run_in_executor(None, feedparser.parse, content)
        
        if feed.bozo:
            logger.warning(f"Feed error for {source['name']}: {feed.bozo_exception}")
        
        articles = []
        for entry in feed.entries[:20]:  # Limit to 20 per source
            title = clean_html(entry.get('title', ''))
            summary = clean_html(entry.get('summary', entry.get('description', '')))
            
            # Truncate summary
            if len(summary) > 500:
                summary = summary[:497] + "..."
            
            # Parse published date
            published_at = None
            if hasattr(entry, 'published_parsed') and entry.published_parsed:
                try:
                    published_at = datetime(*entry.published_parsed[:6])
                except Exception:
                    pass
            
            article = {
                "title": title,
                "summary": summary,
                "image_url": extract_image_url(entry),
                "source": source['name'],
                "category": categorize_article(title, summary),
                "read_time_mins": estimate_read_time(summary),
                "url": entry.get('link', ''),
                "published_at": published_at
            }
            
            if article['title'] and article['url']:
                articles.append(article)
        
        logger.info(f"Fetched {len(articles)} articles from {source['name']}")
        return articles
        
    except Exception as e:
        logger.error(f"Error fetching feed from {source['name']}: {e}")
        return []


async def fetch_all_feeds(force_refresh: bool = False) -> List[dict]:
    """Fetch all RSS feeds concurrently with caching"""
    global _feed_cache, _cache_timestamp
    
    # Check cache validity
    if not force_refresh and _cache_timestamp and _feed_cache:
        cache_age = datetime.utcnow() - _cache_timestamp
        if cache_age < timedelta(minutes=CACHE_TTL_MINUTES):
            logger.info(f"Returning cached feed ({len(_feed_cache)} articles, age: {cache_age.seconds}s)")
            return _feed_cache
    
    logger.info("Fetching fresh RSS feeds...")
    tasks = [fetch_feed(source) for source in FEED_SOURCES]
    results = await asyncio.gather(*tasks)
    
    # Flatten and sort by date
    all_articles = []
    for articles in results:
        all_articles.extend(articles)
    
    # Sort by published date (newest first)
    all_articles.sort(
        key=lambda x: x.get('published_at') or datetime.min,
        reverse=True
    )
    
    # Update cache
    _feed_cache = all_articles
    _cache_timestamp = datetime.utcnow()
    logger.info(f"Cached {len(all_articles)} articles")
    
    return all_articles


async def get_cached_feeds(offset: int = 0, limit: int = 20, category: Optional[str] = None) -> Tuple[List[dict], int]:
    """
    Get paginated feed articles with optional category filter.
    Returns (articles, total_count) tuple.
    """
    all_articles = await fetch_all_feeds()
    
    # Filter by category if specified
    if category and category != "all":
        all_articles = [a for a in all_articles if a.get('category') == category]
    
    total = len(all_articles)
    paginated = all_articles[offset:offset + limit]
    
    return paginated, total


async def sync_feeds_to_db(db):
    """Sync fetched feeds to database"""
    from sqlalchemy import select
    from app.models.models import FeedArticle, ArticleCategory
    
    articles = await fetch_all_feeds()
    
    added = 0
    for article_data in articles:
        # Check if article already exists
        existing = await db.execute(
            select(FeedArticle).where(FeedArticle.url == article_data['url'])
        )
        if existing.scalar_one_or_none():
            continue
        
        # Create new article
        category_map = {
            "alert": ArticleCategory.ALERT,
            "tip": ArticleCategory.TIP,
            "news": ArticleCategory.NEWS
        }
        
        article = FeedArticle(
            title=article_data['title'],
            summary=article_data['summary'],
            image_url=article_data['image_url'],
            source=article_data['source'],
            category=category_map.get(article_data['category'], ArticleCategory.NEWS),
            read_time_mins=article_data['read_time_mins'],
            url=article_data['url'],
            published_at=article_data['published_at']
        )
        db.add(article)
        added += 1
    
    await db.commit()
    logger.info(f"Synced {added} new articles to database")
    return added
