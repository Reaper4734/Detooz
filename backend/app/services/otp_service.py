"""
OTP Service for Email-based Authentication
Uses Gmail SMTP for sending OTPs - FREE (500 emails/day)
"""
import random
import string
import smtplib
import hashlib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from typing import Tuple, Optional
import os

logger = logging.getLogger(__name__)

# In-memory OTP storage (consider Redis for production with multiple workers)
_otp_store: dict = {}


class OTPService:
    """Service for generating, storing, and verifying OTPs"""
    
    OTP_EXPIRY_MINUTES = 5
    OTP_LENGTH = 6
    MAX_ATTEMPTS = 3
    
    @staticmethod
    def generate_otp() -> str:
        """Generate a 6-digit numeric OTP"""
        return ''.join(random.choices(string.digits, k=6))
    
    @staticmethod
    def _hash_otp(otp: str) -> str:
        """Hash OTP for secure storage"""
        return hashlib.sha256(otp.encode()).hexdigest()
    
    @classmethod
    def store_otp(cls, identifier: str, otp: str) -> None:
        """Store OTP with expiry timestamp"""
        _otp_store[identifier.lower()] = {
            'otp_hash': cls._hash_otp(otp),
            'expires_at': datetime.utcnow() + timedelta(minutes=cls.OTP_EXPIRY_MINUTES),
            'attempts': 0,
            'created_at': datetime.utcnow()
        }
        logger.info(f"OTP stored for: {identifier[:3]}***")
    
    @classmethod
    def verify_otp(cls, identifier: str, otp: str) -> Tuple[bool, str]:
        """
        Verify OTP and return (success, message)
        - Checks expiry
        - Limits failed attempts to 3
        - Cleans up after verification
        """
        key = identifier.lower()
        
        if key not in _otp_store:
            return False, "OTP not found. Please request a new one."
        
        stored = _otp_store[key]
        
        # Check expiry
        if datetime.utcnow() > stored['expires_at']:
            del _otp_store[key]
            return False, "OTP expired. Please request a new one."
        
        # Check attempts
        if stored['attempts'] >= cls.MAX_ATTEMPTS:
            del _otp_store[key]
            return False, "Too many failed attempts. Please request a new OTP."
        
        # Verify OTP
        if stored['otp_hash'] != cls._hash_otp(otp):
            stored['attempts'] += 1
            remaining = cls.MAX_ATTEMPTS - stored['attempts']
            return False, f"Invalid OTP. {remaining} attempts remaining."
        
        # Success - clean up
        del _otp_store[key]
        return True, "OTP verified successfully"
    
    @classmethod
    def can_resend(cls, identifier: str) -> Tuple[bool, int]:
        """
        Check if OTP can be resent (rate limiting)
        Returns (can_resend, seconds_remaining)
        """
        key = identifier.lower()
        
        if key not in _otp_store:
            return True, 0
        
        stored = _otp_store[key]
        created = stored.get('created_at', datetime.utcnow())
        cooldown = timedelta(seconds=30)
        
        if datetime.utcnow() < created + cooldown:
            remaining = int((created + cooldown - datetime.utcnow()).total_seconds())
            return False, remaining
        
        return True, 0


class EmailService:
    """Service for sending OTP emails via Gmail SMTP"""
    
    @staticmethod
    def send_otp_email(email: str, otp: str) -> bool:
        """
        Send OTP to email address using Gmail SMTP
        
        Prerequisites:
        1. Enable 2FA on your Gmail account
        2. Create an App Password at https://myaccount.google.com/apppasswords
        3. Set SMTP_USER and SMTP_PASSWORD in .env
        """
        from app.config import settings
        
        try:
            smtp_host = settings.SMTP_HOST
            smtp_port = settings.SMTP_PORT
            smtp_user = settings.SMTP_USER
            smtp_pass = settings.SMTP_PASSWORD
            
            if not smtp_user or not smtp_pass:
                logger.error("SMTP credentials not configured")
                return False
            
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = f'Your Detooz Verification Code: {otp}'
            msg['From'] = f'Detooz <{smtp_user}>'
            msg['To'] = email
            
            # Plain text version
            text = f"""
Your Detooz verification code is: {otp}

This code expires in 5 minutes.

If you didn't request this code, please ignore this email.

- Detooz Team
            """
            
            # HTML version
            html = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 20px; max-width: 500px; margin: 0 auto;">
    <div style="text-align: center; padding: 20px;">
        <h2 style="color: #2563eb; margin-bottom: 8px;">🛡️ Detooz</h2>
        <p style="color: #6b7280; margin-top: 0;">Scam Detection & Protection</p>
    </div>
    
    <div style="background: #f8fafc; border-radius: 12px; padding: 24px; text-align: center;">
        <p style="color: #374151; margin-bottom: 16px;">Your verification code is:</p>
        <div style="background: #ffffff; border: 2px dashed #2563eb; border-radius: 8px; padding: 16px; margin: 0 auto; max-width: 200px;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #1f2937;">{otp}</span>
        </div>
        <p style="color: #9ca3af; font-size: 14px; margin-top: 16px;">
            This code expires in <strong>5 minutes</strong>
        </p>
    </div>
    
    <p style="color: #9ca3af; font-size: 12px; text-align: center; margin-top: 24px;">
        If you didn't request this code, you can safely ignore this email.
    </p>
</body>
</html>
            """
            
            msg.attach(MIMEText(text, 'plain'))
            msg.attach(MIMEText(html, 'html'))
            
            # Send email
            with smtplib.SMTP(smtp_host, smtp_port) as server:
                server.starttls()
                server.login(smtp_user, smtp_pass)
                server.send_message(msg)
            
            logger.info(f"OTP email sent to: {email[:3]}***")
            return True
            
        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"SMTP authentication failed: {e}")
            return False
        except Exception as e:
            logger.error(f"Failed to send email: {e}")
            return False


class SMSService:
    """Service for sending OTP via SMS using Fast2SMS (FREE 10 SMS/day)"""
    
    FAST2SMS_URL = "https://www.fast2sms.com/dev/bulkV2"
    
    @staticmethod
    def send_otp_sms(phone: str, otp: str) -> bool:
        """
        Send OTP to phone number using Fast2SMS
        
        Args:
            phone: Phone number (with or without country code)
            otp: 6-digit OTP code
            
        Returns:
            bool: True if sent successfully
        """
        from app.config import settings
        import requests
        
        try:
            api_key = settings.FAST2SMS_API_KEY
            
            if not api_key:
                logger.error("Fast2SMS API key not configured")
                return False
            
            # Clean phone number (remove country code if present)
            clean_phone = phone.strip()
            if clean_phone.startswith('+91'):
                clean_phone = clean_phone[3:]
            elif clean_phone.startswith('91') and len(clean_phone) > 10:
                clean_phone = clean_phone[2:]
            
            # Fast2SMS API request
            headers = {
                "authorization": api_key,
                "Content-Type": "application/json"
            }
            
            payload = {
                "route": "otp",
                "variables_values": otp,
                "numbers": clean_phone
            }
            
            response = requests.post(
                SMSService.FAST2SMS_URL,
                headers=headers,
                json=payload,
                timeout=10
            )
            
            result = response.json()
            
            if result.get('return') == True:
                logger.info(f"OTP SMS sent to: {clean_phone[:3]}***{clean_phone[-2:]}")
                return True
            else:
                logger.error(f"Fast2SMS error: {result.get('message', 'Unknown error')}")
                return False
                
        except requests.exceptions.Timeout:
            logger.error("Fast2SMS request timeout")
            return False
        except Exception as e:
            logger.error(f"Failed to send SMS: {e}")
            return False
