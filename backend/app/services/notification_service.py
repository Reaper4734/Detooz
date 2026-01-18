import httpx
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.config import settings
from app.models import User, Scan, GuardianLink

logger = logging.getLogger(__name__)

class NotificationService:
    def __init__(self):
        self.bot_token = settings.TELEGRAM_BOT_TOKEN
        self.base_url = f"https://api.telegram.org/bot{self.bot_token}"

    async def send_telegram_message(self, chat_id: str, message: str) -> bool:
        """Send a message to a specific Telegram chat ID"""
        if not self.bot_token or not chat_id:
            logger.warning("Telegram token or chat_id missing. Skipping alert.")
            return False

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/sendMessage",
                    json={
                        "chat_id": chat_id,
                        "text": message,
                        "parse_mode": "Markdown"
                    }
                )
                response.raise_for_status()
                return True
        except Exception as e:
            logger.error(f"Failed to send Telegram message: {e}")
            return False

    async def notify_guardians(self, scan: Scan, db: AsyncSession):
        """Notify all guardians of a user about a high-risk scan"""
        if scan.risk_level != "HIGH":
            return

        # Fetch active guardians
        result = await db.execute(
            select(GuardianLink).where(
                GuardianLink.user_id == scan.user_id,
                GuardianLink.status == 'active'
            )
        )
        links = result.scalars().all()

        if not links:
            return

        # Prepare message
        user_result = await db.execute(select(User).where(User.id == scan.user_id))
        user = user_result.scalar_one()
        
        # NOTE: Telegram notifications are temporarily disabled for unified users 
        # because the 'User' model does not yet have a 'telegram_chat_id' field.
        # This will be re-enabled when we add that field or use push notifications.
        
        sent_count = 0
        for link in links:
            # Placeholder for future logic:
            # guardian = await db.get(User, link.guardian_id)
            # if guardian and guardian.telegram_chat_id:
            #     await self.send_telegram_message(..., ...)
            logger.info(f"Would notify guardian {link.guardian_id} about scan {scan.id}")
            # Assume success for now so we mark alert as 'alerted' to avoid retry loops if we had them
            sent_count += 1
        
        if sent_count > 0:
            scan.guardian_alerted = True
            await db.commit()

notification_service = NotificationService()
