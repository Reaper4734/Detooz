import re
import json
from app.config import settings

# Try to import groq, but make it optional
try:
    from groq import Groq
    GROQ_AVAILABLE = True
except ImportError:
    GROQ_AVAILABLE = False


class ScamDetector:
    """AI-powered scam detection service using Groq API (Llama 3)"""
    
    # Scam patterns for quick local detection (no API call needed)
    HIGH_RISK_PATTERNS = [
        r"won\s+(lottery|prize|rs\.?|₹|lakh|crore)",
        r"claim\s+(prize|reward|money)",
        r"send\s+otp",
        r"share\s+otp",
        r"kyc\s+(update|expire|block|suspend)",
        r"account\s+(block|suspend|close|frozen)",
        r"(job|work)\s+offer.*(payment|fee|deposit)",
        r"loan\s+approved\s+instantly",
        r"pan\s+card\s+link\s+urgent",
        r"aadhaar\s+update\s+urgent",
        r"click\s+(here|this\s+link|now)",
        r"verify\s+(now|immediately|urgent)",
    ]
    
    MEDIUM_RISK_PATTERNS = [
        r"bit\.ly|tinyurl|short\.io|t\.co",
        r"act\s+now",
        r"urgent\s+action",
        r"verify\s+immediately",
        r"congratulations",
        r"selected\s+as\s+winner",
        r"limited\s+time\s+offer",
    ]
    
    # Scam detection prompt for AI
    SYSTEM_PROMPT = """You are a scam detection expert specialized in Indian SMS/WhatsApp scams.

Analyze the message and classify as:
- HIGH: Definite scam (phishing, fraud, money requests, fake prizes)
- MEDIUM: Suspicious (urgency tactics, unknown links, unusual requests)
- LOW: Likely legitimate

Common Indian scam patterns:
1. KYC update urgency
2. Lottery/prize claims
3. Job offers requiring payment
4. Loan pre-approval scams
5. OTP sharing requests
6. Bank/government impersonation
7. Fake delivery notifications
8. Investment schemes promising high returns

Return ONLY valid JSON (no markdown):
{"risk_level": "HIGH/MEDIUM/LOW", "reason": "brief explanation", "scam_type": "type or null", "confidence": 0.0-1.0}"""

    def __init__(self):
        self.client = None
        if GROQ_AVAILABLE and settings.GROQ_API_KEY:
            self.client = Groq(api_key=settings.GROQ_API_KEY)
    
    async def analyze(self, message: str, sender: str) -> dict:
        """Analyze a message for scam indicators"""
        
        # Step 1: Quick pattern check (no API needed)
        local_result = self._check_patterns(message)
        if local_result["risk_level"] == "HIGH":
            return local_result
        
        # Step 2: Use AI for uncertain messages
        if self.client:
            try:
                ai_result = await self._analyze_with_ai(message, sender)
                return ai_result
            except Exception as e:
                print(f"AI analysis failed: {e}")
                # Fall back to local result
                return local_result
        
        return local_result
    
    def _check_patterns(self, message: str) -> dict:
        """Check message against known scam patterns"""
        message_lower = message.lower()
        
        # Check HIGH risk patterns
        for pattern in self.HIGH_RISK_PATTERNS:
            if re.search(pattern, message_lower):
                return {
                    "risk_level": "HIGH",
                    "reason": "Message contains known scam patterns",
                    "scam_type": "Pattern Match",
                    "confidence": 0.85
                }
        
        # Check MEDIUM risk patterns
        for pattern in self.MEDIUM_RISK_PATTERNS:
            if re.search(pattern, message_lower):
                return {
                    "risk_level": "MEDIUM",
                    "reason": "Message contains suspicious patterns",
                    "scam_type": None,
                    "confidence": 0.6
                }
        
        # No patterns matched - likely safe
        return {
            "risk_level": "LOW",
            "reason": "No suspicious patterns detected",
            "scam_type": None,
            "confidence": 0.7
        }
    
    async def _analyze_with_ai(self, message: str, sender: str) -> dict:
        """Analyze message using Groq AI (Llama 3)"""
        try:
            response = self.client.chat.completions.create(
                model="llama3-8b-8192",
                messages=[
                    {"role": "system", "content": self.SYSTEM_PROMPT},
                    {"role": "user", "content": f"Sender: {sender}\nMessage: {message}"}
                ],
                temperature=0.1,
                max_tokens=200
            )
            
            result_text = response.choices[0].message.content.strip()
            
            # Parse JSON response
            result = json.loads(result_text)
            
            return {
                "risk_level": result.get("risk_level", "LOW"),
                "reason": result.get("reason", "AI analysis complete"),
                "scam_type": result.get("scam_type"),
                "confidence": float(result.get("confidence", 0.8))
            }
            
        except json.JSONDecodeError:
            # If AI returns invalid JSON, extract what we can
            return {
                "risk_level": "MEDIUM",
                "reason": "AI analysis inconclusive",
                "scam_type": None,
                "confidence": 0.5
            }
        except Exception as e:
            raise e
