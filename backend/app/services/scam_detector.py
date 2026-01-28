import json
import base64
import asyncio
import torch
import torch.nn.functional as F
from transformers import MobileBertTokenizerFast, MobileBertForSequenceClassification
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


# Module-level cache for Groq API calls (avoids @lru_cache on instance method)
# Key: (message, sender) -> dict result
_groq_cache: dict[tuple[str, str], dict] = {}
_GROQ_CACHE_MAX_SIZE = 1024


class ScamDetector:
    """AI-powered scam detection service supporting Groq and OpenRouter (Gemma/Gemini)"""
    
    # Scam detection prompt for AI - Supports all 22 Indian scheduled languages
    SYSTEM_PROMPT = """You are a scam detection expert specialized in Indian SMS/WhatsApp scams.
    
    SUPPORTED LANGUAGES (all 22 scheduled languages of India):
    1. Hindi (हिन्दी) - Devanagari
    2. Bengali (বাংলা) - Bengali script
    3. Telugu (తెలుగు) - Telugu script
    4. Marathi (मराठी) - Devanagari
    5. Tamil (தமிழ்) - Tamil script
    6. Urdu (اردو) - Perso-Arabic
    7. Gujarati (ગુજરાતી) - Gujarati script
    8. Kannada (ಕನ್ನಡ) - Kannada script
    9. Odia (ଓଡ଼ିଆ) - Odia script
    10. Malayalam (മലയാളം) - Malayalam script
    11. Punjabi (ਪੰਜਾਬੀ) - Gurmukhi
    12. Assamese (অসমীয়া) - Assamese script
    13. Maithili (मैथिली) - Devanagari
    14. Sanskrit (संस्कृतम्) - Devanagari
    15. Santali (ᱥᱟᱱᱛᱟᱲᱤ) - Ol Chiki
    16. Nepali (नेपाली) - Devanagari
    17. Sindhi (سنڌي) - Perso-Arabic
    18. Konkani (कोंकणी) - Devanagari
    19. Dogri (डोगरी) - Devanagari
    20. Kashmiri (कॉशुर) - Perso-Arabic
    21. Manipuri/Meitei (মৈতৈলোন্) - Meitei script
    22. Bodo (बड़ो) - Devanagari

    The message may be in:
    - Native script (e.g., "आपका खाता ब्लॉक है")
    - Transliterated/Romanized (e.g., "aapka khata block hai")  
    - Mixed language - Hinglish, Tanglish, Benglish etc. (e.g., "Your account block ho gaya")
    - Regional dialects and variations

    IMPORTANT: Translate and understand the message internally, then analyze for scam intent.

    Analyze the message and classify as:
    - HIGH: Definite scam (phishing, fraud, money requests, fake prizes)
    - MEDIUM: Suspicious (urgency tactics, unknown links, unusual requests)
    - LOW: Likely legitimate

    Common Indian scam patterns (in any language):
    1. KYC update urgency - "Your account will be blocked" / "आपका खाता ब्लॉक होगा"
    2. Lottery/prize claims - "Congratulations you won" / "बधाई हो आपने जीता"
    3. Job offers requiring payment - "Pay registration fee" / "रजिस्ट्रेशन फीस भरें"
    4. Loan pre-approval scams - "Instant loan approved" / "तुरंत लोन मंजूर"
    5. OTP sharing requests - "Share your OTP" / "अपना OTP बताएं"
    6. Bank/government impersonation - "Dear customer, account suspended"
    7. Fake delivery notifications - "Package held, pay customs"
    8. Investment schemes - "Guaranteed returns" / "गारंटीड रिटर्न"
    9. UPI fraud - "Scan QR to receive money" / "पैसे पाने के लिए QR स्कैन करें"
    10. Fake family emergency - "Urgent money needed" / "तुरंत पैसे चाहिए"

    Return ONLY valid JSON (no markdown):
    {"risk_level": "HIGH/MEDIUM/LOW", "reason": "brief explanation in English", "scam_type": "type or null", "confidence": 0.0-1.0, "original_language": "detected language (e.g., Hindi, Tamil, Bengali, English, Hinglish)"}"""

    
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

        # Local Model Initialization
        self.local_model = None
        self.local_tokenizer = None
        try:
            # Robust Path Logic
            import os
            base_dir = os.getcwd()
            # Try multiple expected locations
            possible_paths = [
                os.path.join(base_dir, "ml_pipeline", "data", "en_hinglish", "saved_model"), # Trained model location
                os.path.join(base_dir, "ml_pipeline", "saved_model"), # If in backend/
                os.path.join(base_dir, "backend", "ml_pipeline", "data", "en_hinglish", "saved_model"), # If in root
                os.path.join(base_dir, "backend", "ml_pipeline", "saved_model"), # If in root
                "./ml_pipeline/saved_model" # Fallback
            ]
            
            model_path = None
            for p in possible_paths:
                # Check if directory has actual model weights (safetensors or bin)
                if os.path.exists(p):
                    has_weights = (os.path.exists(os.path.join(p, "model.safetensors")) or 
                                   os.path.exists(os.path.join(p, "pytorch_model.bin")))
                    if has_weights and os.path.exists(os.path.join(p, "config.json")):
                        model_path = p
                        break
            
            if model_path:
                print(f"DEBUG: Loading Local Model from {model_path}...")
                self.local_tokenizer = MobileBertTokenizerFast.from_pretrained(model_path)
                self.local_model = MobileBertForSequenceClassification.from_pretrained(model_path)
                self.local_model.eval()
                
                # Use GPU if available
                self.device = "cuda" if torch.cuda.is_available() else "cpu"
                self.local_model.to(self.device)
                print(f"DEBUG: Local Model Loaded on {self.device}")
            else:
                 print(f"INFO: Local MobileBERT model not found. Running in Cloud-Optimized Mode.")
                 print(f"INFO: Enhanced Pattern Matching active for offline protection.")

        except Exception as e:
            print(f"INFO: Local AI Init skipped ({str(e)}). Using Cloud + Patterns.")

    
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
        
        # Step 2: Use Local AI Model (MobileBERT)
        if self.local_model:
            local_ai_result = await self._analyze_with_local_model(message)
            # If Local AI is confident, use its result and save Groq tokens
            if local_ai_result["confidence"] > 0.90:
                 print(f"DEBUG: Local AI confident ({local_ai_result['risk_level']}), skipping Groq.")
                 return local_ai_result
            
            # If undecided but leaning towards scam, carry over context or just fall through

        
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

    async def _analyze_with_local_model(self, message: str) -> dict:
        """Run inference on the local MobileBERT model"""
        try:
            # Tokenize
            inputs = self.local_tokenizer(
                message, 
                return_tensors="pt", 
                truncation=True, 
                padding=True,
                max_length=128
            ).to(self.device)
            
            # Predict
            with torch.no_grad():
                outputs = self.local_model(**inputs)
                probs = F.softmax(outputs.logits, dim=1)
                confidence, predicted_class = torch.max(probs, dim=1)
                
            # Map Label (0=ham, 1=otp, 2=scam) - Must match training!
            label_idx = predicted_class.item()
            conf_score = confidence.item()
            
            if label_idx == 2: # SCAM
                return {
                    "risk_level": "HIGH",
                    "reason": "Flagged by Local MobileBERT",
                    "scam_type": "Suspected Scam",
                    "confidence": conf_score
                }
            elif label_idx == 1: # OTP
                return {
                    "risk_level": "LOW", # OTPs are safe but sensitive
                    "reason": "Transactional OTP",
                    "scam_type": "OTP",
                    "confidence": conf_score
                }
            else: # HAM
                return {
                    "risk_level": "LOW",
                    "reason": "Safe conversation",
                    "scam_type": None,
                    "confidence": conf_score
                }
                
        except Exception as e:
            print(f"WARN: Local Model Inference Failed: {e}")
            return {"risk_level": "UNKNOWN", "confidence": 0.0}
    
    def _sync_groq_call(self, message: str, sender: str) -> dict:
        """Synchronous Groq API call with module-level caching"""
        global _groq_cache
        
        # Check cache first
        cache_key = (message, sender)
        if cache_key in _groq_cache:
            print(f"DEBUG: Cache hit for message from {sender}")
            return _groq_cache[cache_key]
        
        # Make API call
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
        result = json.loads(result_text)
        
        # Store in cache (with size limit)
        if len(_groq_cache) >= _GROQ_CACHE_MAX_SIZE:
            # Remove oldest entry (first key)
            oldest_key = next(iter(_groq_cache))
            del _groq_cache[oldest_key]
        _groq_cache[cache_key] = result
        
        return result
    
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
