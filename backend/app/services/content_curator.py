"""
Detooz Exclusive Content Curator
Uses Groq AI to generate educational content from RSS feeds
"""
import asyncio
import json
import logging
from datetime import datetime
from typing import List, Optional
from PIL import Image, ImageDraw, ImageFont
import aiohttp
import io

logger = logging.getLogger(__name__)


async def create_educational_content(articles: List[dict], groq_api_key: str) -> Optional[dict]:
    """
    Convert RSS news articles into actionable safety education
    using Groq AI.
    """
    if not articles:
        logger.warning("No articles provided for curation")
        return None
    
    # Combine top 5 articles for context
    news_context = "\n".join([
        f"- {a.get('title', 'Unknown')}: {a.get('summary', '')[:200]}" 
        for a in articles[:5]
    ])
    
    prompt = f"""Based on these recent cybersecurity news from India:
{news_context}

Create ONE educational article for Detooz users.

FORMAT (use exact structure):
🚨 THREAT: [Short catchy title, max 10 words]

📰 What's Happening:
[2-3 sentences explaining the current threat in simple language]

⚠️ If This Happens to You:
1. [Immediate action step]
2. [Report/Block step]
3. [Prevention tip]

✅ Detooz Safety Tip:
[One memorable rule, like "Banks NEVER ask for OTP"]

RULES:
- Keep language simple (age 15-60)
- Focus on Indian context (UPI, OTP, WhatsApp scams)
- Be actionable, not just informative
- Max 150 words total"""

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {groq_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "llama-3.1-8b-instant",
                    "messages": [
                        {"role": "system", "content": "You are a cybersecurity educator helping Indian users stay safe from scams."},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 500
                },
                timeout=30
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    logger.error(f"Groq API error: {response.status} - {error_text}")
                    return None
                
                data = await response.json()
                content = data["choices"][0]["message"]["content"]
                
                # Extract title from content (first line after 🚨 THREAT:)
                title = "Safety Alert"
                lines = content.split("\n")
                for line in lines:
                    if "THREAT:" in line:
                        title = line.replace("🚨", "").replace("THREAT:", "").strip()
                        break
                
                # Get image from first article with image
                image_url = None
                for a in articles[:5]:
                    if a.get('image_url'):
                        image_url = a['image_url']
                        break
                
                # Source URLs for attribution
                source_urls = [a.get('url', '') for a in articles[:5] if a.get('url')]
                
                return {
                    "title": title,
                    "content": content,
                    "image_url": image_url,
                    "source_articles": json.dumps(source_urls),
                    "created_at": datetime.utcnow()
                }
                
    except Exception as e:
        logger.error(f"Error creating educational content: {e}")
        return None


async def add_watermark_to_image(image_url: str, watermark_text: str = "Detooz") -> Optional[bytes]:
    """
    Download image and add Detooz watermark overlay.
    Returns the watermarked image as bytes.
    """
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(image_url, timeout=10) as response:
                if response.status != 200:
                    return None
                image_data = await response.read()
        
        # Open image with PIL
        img = Image.open(io.BytesIO(image_data))
        
        # Create a drawing context
        draw = ImageDraw.Draw(img)
        
        # Calculate position (bottom-right corner)
        width, height = img.size
        
        # Use a simple font (or load a custom one)
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
        except:
            font = ImageFont.load_default()
        
        # Add semi-transparent watermark
        text = f"🛡️ {watermark_text}"
        text_bbox = draw.textbbox((0, 0), text, font=font)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        
        x = width - text_width - 10
        y = height - text_height - 10
        
        # Draw background rectangle
        draw.rectangle([x - 5, y - 5, x + text_width + 5, y + text_height + 5], fill=(0, 0, 0, 128))
        
        # Draw text
        draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))
        
        # Save to bytes
        output = io.BytesIO()
        img.save(output, format='PNG')
        return output.getvalue()
        
    except Exception as e:
        logger.error(f"Error adding watermark: {e}")
        return None


async def generate_exclusive_content(db, groq_api_key: str):
    """
    Main function to generate Detooz Exclusive content.
    Called by scheduler or admin endpoint.
    """
    from app.services.feed_aggregator import fetch_all_feeds
    from app.models.models import DetoozExclusive, ArticleCategory
    
    logger.info("Starting Detooz Exclusive content generation...")
    
    # Fetch fresh RSS articles
    articles = await fetch_all_feeds()
    
    if not articles:
        logger.warning("No articles fetched from RSS feeds")
        return None
    
    logger.info(f"Fetched {len(articles)} articles, generating educational content...")
    
    # Generate educational content using Groq
    content = await create_educational_content(articles, groq_api_key)
    
    if not content:
        logger.error("Failed to generate educational content")
        return None
    
    # Create DetoozExclusive record
    exclusive = DetoozExclusive(
        title=content["title"],
        content=content["content"],
        source_articles=content["source_articles"],
        image_url=content["image_url"],
        category=ArticleCategory.ALERT,
        read_time_mins=2,
        is_active=True
    )
    
    db.add(exclusive)
    await db.commit()
    await db.refresh(exclusive)
    
    logger.info(f"Created Detooz Exclusive: {exclusive.title}")
    return exclusive
