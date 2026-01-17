import json
import base64
from functools import lru_cache
import asyncio
from app.config import settings
from app.services.sms_patterns import check_patterns

# Try to import groq, but make it optional
try:
    from groq import Groq
    GROQ_AVAILABLE = True
except ImportError:
    GROQ_AVAILABLE = False

# Import OpenAI for OpenRouter
try:
    from openai import OpenAI
    OPENROUTER_AVAILABLE = True
except ImportError:
    OPENROUTER_AVAILABLE = False


class ScamDetector:
    """AI-powered scam detection service supporting Groq and OpenRouter (Gemma/Gemini)"""
    
    # Scam detection prompt for AI
    SYSTEM_PROMPT = """You are a scam detection expert specialized in Indian SMS/WhatsApp scams.
    
    The message may be in English, Hindi, Hinglish, or other Indian languages.
    Translate internally if needed, then analyze logic for scam intent.

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
    {"risk_level": "HIGH/MEDIUM/LOW", "reason": "brief explanation in English", "scam_type": "type or null", "confidence": 0.0-1.0, "original_language": "detected language"}"""

    def __init__(self):
        self.client = None
        if GROQ_AVAILABLE and settings.GROQ_API_KEY:
            self.client = Groq(api_key=settings.GROQ_API_KEY)
            
        self.router_client = None
        if OPENROUTER_AVAILABLE and settings.OPENROUTER_API_KEY:
            try:
                self.router_client = OpenAI(
                    base_url="https://openrouter.ai/api/v1",
                    api_key=settings.OPENROUTER_API_KEY,
                )
                print("DEBUG: OpenRouter Initialized successfully")
            except Exception as e:
                print(f"DEBUG: OpenRouter Init Failed: {e}")
    
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
        # Return immediately if confident (HIGH scam or verified LOW)
        if (local_result["risk_level"] == "HIGH" and local_result["confidence"] >= 0.85) or \
           (local_result["risk_level"] == "LOW" and local_result["confidence"] >= 0.9):
            return {
                "risk_level": local_result["risk_level"],
                "reason": local_result["reason"],
                "scam_type": local_result["scam_type"],
                "confidence": local_result["confidence"]
            }
        
        # Step 2: Use AI for uncertain messages (MEDIUM or LOW from patterns)
        if self.client:
            try:
                print(f"DEBUG: Calling Groq AI for: {message[:50]}...")
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
    
    @lru_cache(maxsize=1024)
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
        print(f"DEBUG: Groq Response: {result_text}")
        # Clean up if AI responds with ```json ... ```
        if result_text.startswith("```"):
            result_text = result_text.replace("```json", "").replace("```", "").strip()
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
        
    async def analyze_image(self, image_data: bytes) -> dict:
        """
        Analyze an image for scam content using OpenRouter (Gemma/Gemini).
        """
        if not self.router_client:
            print("DEBUG: OpenRouter client not initialized")
            return {
                "risk_level": "UNKNOWN",
                "reason": "Image analysis not configured (OpenRouter API missing)",
                "confidence": 0.0
            }
            
        try:
            print("DEBUG: Calling OpenRouter (Gemma-3) Vision API...")
            # Run OpenRouter call in thread pool
            result = await asyncio.to_thread(self._sync_openrouter_call, image_data)
            return result
        except Exception as e:
            print(f"DEBUG: OpenRouter analysis failed: {e}")
            return {
                "risk_level": "UNKNOWN",
                "reason": f"Analysis failed: {str(e)}",
                "confidence": 0.0
            }
            
    def _sync_openrouter_call(self, image_data: bytes) -> dict:
        """Synchronous OpenRouter API call with multiple model fallback"""
        import re
        import time
        
        # Encode image to base64
        base64_image = base64.b64encode(image_data).decode('utf-8')
        
        prompt = """Analyze this image for scam/fraud content.
        Indian context: fake payment screens, suspicious WhatsApp chats, fake lottery/prize messages.
        Return JSON ONLY:
        {"risk_level": "HIGH/MEDIUM/LOW", "reason": "short explanation in English", "scam_type": "type"}"""

        # List of models to try in order of reliability/speed for vision
        models_to_try = [
            "google/gemini-2.0-flash-exp:free",
            "meta-llama/llama-3.2-11b-vision-instruct:free",
            "google/gemini-2.0-flash-001", # Non-free version if user has credits
            "qwen/qwen-2-vl-7b-instruct:free"
        ]
        
        last_error = "No models tried"

        for model in models_to_try:
            try:
                print(f"DEBUG: Attempting image analysis with {model}...")
                start_time = time.time()
                
                response = self.router_client.chat.completions.create(
                    model=model,
                    messages=[
                        {
                            "role": "user",
                            "content": [
                                {"type": "text", "text": prompt},
                                {
                                    "type": "image_url",
                                    "image_url": {
                                        "url": f"data:image/jpeg;base64,{base64_image}"
                                    }
                                }
                            ]
                        }
                    ],
                    max_tokens=200,
                    timeout=25 # Strict 25s timeout per model
                )
                
                text = response.choices[0].message.content.strip()
                print(f"DEBUG: {model} responded in {time.time() - start_time:.1f}s")
                print(f"DEBUG: Raw Response: {text}")
                
                # Clean up JSON
                if "{" in text:
                    match = re.search(r'\{.*\}', text, re.DOTALL)
                    if match:
                        text = match.group(0)
                
                return json.loads(text)
                
            except Exception as e:
                print(f"DEBUG: Model {model} failed: {e}")
                last_error = str(e)
                continue # Try next model
        
        # If all models fail, return a safe error response
        print(f"DEBUG: All vision models failed. Last error: {last_error}")
        return {
            "risk_level": "UNKNOWN",
            "reason": f"AI models currently unavailable (429/Timeout). Please retry in 5 mins.",
            "scam_type": "Service Busy",
            "confidence": 0.0
        }
