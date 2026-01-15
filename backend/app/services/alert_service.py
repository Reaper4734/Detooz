import httpx
from app.config import settings


class AlertService:
    """Multi-channel alert service - WhatsApp (CallMeBot) + Telegram"""
    
    CALLMEBOT_URL = "https://api.callmebot.com/whatsapp.php"
    TELEGRAM_URL = "https://api.telegram.org/bot{token}/sendMessage"
    
    async def send_scam_alert(
        self,
        phone: str,
        apikey: str,
        user_name: str,
        sender: str,
        risk_level: str,
        reason: str,
        telegram_chat_id: str = None,
        telegram_bot_token: str = None
    ) -> bool:
        """Send scam alert to guardian via WhatsApp or Telegram"""
        
        message = (
            f"🚨 *SCAM ALERT - Detooz*\n\n"
            f"📱 *{user_name}* received a suspicious message\n\n"
            f"📨 From: {sender}\n"
            f"⚠️ Risk: *{risk_level}*\n"
            f"📝 Reason: {reason}\n\n"
            f"_Please check on them and advise caution._\n"
            f"_Sent by Detooz ScamShield_"
        )
        
        # Try WhatsApp first
        if settings.CALLMEBOT_ENABLED and apikey:
            success = await self._send_whatsapp(phone, apikey, message)
            if success:
                return True
        
        # Fallback to Telegram
        if telegram_chat_id and telegram_bot_token:
            success = await self._send_telegram(
                telegram_bot_token, 
                telegram_chat_id, 
                message
            )
            if success:
                return True
        
        # Try global Telegram bot if configured
        if settings.TELEGRAM_BOT_TOKEN and telegram_chat_id:
            success = await self._send_telegram(
                settings.TELEGRAM_BOT_TOKEN,
                telegram_chat_id,
                message
            )
            if success:
                return True
        
        return False
    
    async def send_test_alert(
        self,
        phone: str,
        apikey: str,
        user_name: str,
        telegram_chat_id: str = None,
        telegram_bot_token: str = None
    ) -> bool:
        """Send test alert to verify guardian setup"""
        
        message = (
            f"✅ *Detooz Test Alert*\n\n"
            f"This is a test message from Detooz.\n"
            f"You are now set up as a guardian for *{user_name}*.\n\n"
            f"You will receive alerts when they get scam messages.\n\n"
            f"_Guardian protection is now active!_ 🛡️"
        )
        
        # Try WhatsApp first
        if apikey:
            success = await self._send_whatsapp(phone, apikey, message)
            if success:
                return True
        
        # Fallback to Telegram
        if telegram_chat_id:
            token = telegram_bot_token or settings.TELEGRAM_BOT_TOKEN
            if token:
                success = await self._send_telegram(token, telegram_chat_id, message)
                if success:
                    return True
        
        return False
    
    async def _send_whatsapp(self, phone: str, apikey: str, message: str) -> bool:
        """Send WhatsApp message via CallMeBot"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    self.CALLMEBOT_URL,
                    params={
                        "phone": phone,
                        "text": message,
                        "apikey": apikey
                    },
                    timeout=30.0
                )
                return response.status_code == 200
        except Exception as e:
            print(f"WhatsApp alert failed: {e}")
            return False
    
    async def _send_telegram(
        self, 
        bot_token: str, 
        chat_id: str, 
        message: str
    ) -> bool:
        """Send Telegram message via Bot API (FREE, unlimited!)"""
        try:
            url = self.TELEGRAM_URL.format(token=bot_token)
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    url,
                    json={
                        "chat_id": chat_id,
                        "text": message,
                        "parse_mode": "Markdown"
                    },
                    timeout=30.0
                )
                return response.status_code == 200
        except Exception as e:
            print(f"Telegram alert failed: {e}")
            return False
