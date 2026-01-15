import httpx
from app.config import settings


class AlertService:
    """WhatsApp alert service using CallMeBot (FREE)"""
    
    CALLMEBOT_URL = "https://api.callmebot.com/whatsapp.php"
    
    async def send_scam_alert(
        self,
        phone: str,
        apikey: str,
        user_name: str,
        sender: str,
        risk_level: str,
        reason: str
    ) -> bool:
        """Send scam alert to guardian via WhatsApp"""
        
        if not settings.CALLMEBOT_ENABLED:
            return False
        
        message = (
            f"🚨 *SCAM ALERT - Detooz*\n\n"
            f"📱 *{user_name}* received a suspicious message\n\n"
            f"📨 From: {sender}\n"
            f"⚠️ Risk: *{risk_level}*\n"
            f"📝 Reason: {reason}\n\n"
            f"_Please check on them and advise caution._\n"
            f"_Sent by Detooz ScamShield_"
        )
        
        return await self._send_whatsapp(phone, apikey, message)
    
    async def send_test_alert(
        self,
        phone: str,
        apikey: str,
        user_name: str
    ) -> bool:
        """Send test alert to verify guardian setup"""
        
        message = (
            f"✅ *Detooz Test Alert*\n\n"
            f"This is a test message from Detooz.\n"
            f"You are now set up as a guardian for *{user_name}*.\n\n"
            f"You will receive alerts when they get scam messages.\n\n"
            f"_Guardian protection is now active!_ 🛡️"
        )
        
        return await self._send_whatsapp(phone, apikey, message)
    
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
            print(f"Failed to send WhatsApp alert: {e}")
            return False
