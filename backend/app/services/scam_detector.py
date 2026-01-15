import json
import asyncio
from app.config import settings
from app.services.sms_patterns import check_patterns

# Try to import groq, but make it optional
try:
    from groq import Groq
    GROQ_AVAILABLE = True
except ImportError:
    GROQ_AVAILABLE = False


class ScamDetector:
    """AI-powered scam detection service using Groq API (Llama 3.3) + local patterns"""
    
    # Scam detection prompt for AI
    SYSTEM_PROMPT = """You are a scam detection expert specialized in Indian SMS/WhatsApp scams.

Analyze the message and classify as:
- HIGH: Definite scam (phishing, fraud, money requests, fake prizes)
- MEDIUM: Suspicious (urgency tactics, unknown links, unusual requests)
- LOW: Likely legitimate

Common Indian scam patterns:
1. KYC update urgency - "Your account will be blocked"
2. Lottery/prize claims - "Congratulations you won Rs 50 lakh"
3. Job offers requiring payment - "Pay Rs 500 registration fee"
4. Loan pre-approval scams - "Instant loan approved"
5. OTP sharing requests - "Share your OTP"
6. Bank/government impersonation - "Dear customer, account suspended"
7. Fake delivery notifications - "Package held, pay customs"
8. Investment schemes - "Guaranteed 50% returns daily"
9. UPI fraud - "Scan QR to receive money"
10. Fake family emergency - "Mom is in hospital, send money"

Return ONLY valid JSON (no markdown):
{"risk_level": "HIGH/MEDIUM/LOW", "reason": "brief explanation", "scam_type": "type or null", "confidence": 0.0-1.0}"""

    def __init__(self):
        self.client = None
        if GROQ_AVAILABLE and settings.GROQ_API_KEY:
            self.client = Groq(api_key=settings.GROQ_API_KEY)
    
    async def analyze(self, message: str, sender: str) -> dict:
        """
        Analyze a message for scam indicators.
        
        Two-stage detection:
        1. Fast local pattern matching (covers ~90% of scams)
        2. AI analysis for uncertain messages (smarter but slower)
        """
        
        # Step 1: Quick pattern check using comprehensive patterns
        local_result = check_patterns(message, sender)
        
        # If HIGH confidence from patterns, no need for AI
        if local_result["risk_level"] == "HIGH" and local_result["confidence"] >= 0.85:
            return {
                "risk_level": local_result["risk_level"],
                "reason": local_result["reason"],
                "scam_type": local_result["scam_type"],
                "confidence": local_result["confidence"]
            }
        
        # Step 2: Use AI for uncertain messages (MEDIUM or LOW from patterns)
        if self.client:
            try:
                ai_result = await self._analyze_with_ai(message, sender)
                
                # If AI says HIGH and patterns say MEDIUM, trust AI
                if ai_result["risk_level"] == "HIGH":
                    return ai_result
                
                # If patterns say MEDIUM but AI says LOW, return MEDIUM (safer)
                if local_result["risk_level"] == "MEDIUM" and ai_result["risk_level"] == "LOW":
                    return {
                        "risk_level": "MEDIUM",
                        "reason": local_result["reason"],
                        "scam_type": local_result["scam_type"],
                        "confidence": max(local_result["confidence"], 0.5)
                    }
                
                return ai_result
                
            except Exception as e:
                print(f"AI analysis failed: {e}")
                # Fall back to local result
                return {
                    "risk_level": local_result["risk_level"],
                    "reason": local_result["reason"],
                    "scam_type": local_result["scam_type"],
                    "confidence": local_result["confidence"]
                }
        
        # No AI available, use local result
        return {
            "risk_level": local_result["risk_level"],
            "reason": local_result["reason"],
            "scam_type": local_result["scam_type"],
            "confidence": local_result["confidence"]
        }
    
    def _sync_groq_call(self, message: str, sender: str) -> dict:
        """Synchronous Groq API call (will be run in thread pool)"""
        response = self.client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": self.SYSTEM_PROMPT},
                {"role": "user", "content": f"Sender: {sender}\nMessage: {message}"}
            ],
            temperature=0.1,
            max_tokens=200
        )
        
        result_text = response.choices[0].message.content.strip()
        return json.loads(result_text)
    
    async def _analyze_with_ai(self, message: str, sender: str) -> dict:
        """Analyze message using Groq AI (Llama 3.3) - runs sync call in thread pool"""
        try:
            # Run sync Groq call in thread pool to not block event loop
            result = await asyncio.to_thread(self._sync_groq_call, message, sender)
            
            return {
                "risk_level": result.get("risk_level", "LOW"),
                "reason": result.get("reason", "AI analysis complete"),
                "scam_type": result.get("scam_type"),
                "confidence": float(result.get("confidence", 0.8))
            }
            
        except json.JSONDecodeError:
            # If AI returns invalid JSON, return MEDIUM as safe default
            return {
                "risk_level": "MEDIUM",
                "reason": "AI analysis inconclusive",
                "scam_type": None,
                "confidence": 0.5
            }
        except Exception as e:
            raise e
    
    async def analyze_quick(self, message: str, sender: str = "") -> dict:
        """
        Quick analysis using only patterns (no AI).
        Faster, suitable for batch processing.
        """
        result = check_patterns(message, sender)
        return {
            "risk_level": result["risk_level"],
            "reason": result["reason"],
            "scam_type": result["scam_type"],
            "confidence": result["confidence"]
        }
