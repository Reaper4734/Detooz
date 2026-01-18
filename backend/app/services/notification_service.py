import httpx
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.config import settings
from app.models import Guardian, User, Scan

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

        # Fetch guardians with telegram_chat_id
        result = await db.execute(
            select(Guardian).where(
                Guardian.user_id == scan.user_id,
                Guardian.telegram_chat_id.isnot(None)
            )
        )
        guardians = result.scalars().all()

        if not guardians:
            return

        # Prepare message
        user_result = await db.execute(select(User).where(User.id == scan.user_id))
        user = user_result.scalar_one()
        
        alert_message = (
            f"🚨 *ScamShield Alert* 🚨\n\n"
            f"Your protégé *{user.name}* just encountered a HIGH RISK message.\n\n"
            f"📝 *Content:* \"{scan.message_preview}\"\n"
            f"🚫 *Type:* {scan.scam_type or 'Suspicious'}\n"
            f"⚠️ *Reason:* {scan.risk_reason}\n\n"
            f"Please check on them immediately."
        )

        # Send to all guardians
        sent_count = 0
        for guardian in guardians:
            success = await self.send_telegram_message(guardian.telegram_chat_id, alert_message)
            if success:
                sent_count += 1
                guardian.last_alert_sent = scan.created_at
        
        if sent_count > 0:
            scan.guardian_alerted = True
            await db.commit()

notification_service = NotificationService()
