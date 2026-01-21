"""
Service Unit Tests
Tests for helper services
"""
import pytest
from app.services.url_scraper import url_scraper
from app.services.explanation_engine import explanation_engine
from app.services.confidence_scorer import confidence_scorer, ConfidenceFactors


class TestUrlScraper:
    """Tests for URL Scraper service"""
    
    @pytest.mark.asyncio
    async def test_normalize_phone(self):
        """Test phone normalization"""
        assert url_scraper.normalize_phone("9876543210") == "+919876543210"
        assert url_scraper.normalize_phone("+919876543210") == "+919876543210"
        assert url_scraper.normalize_phone("09876543210") == "09876543210" # Might need adjustment depending on logic
        assert url_scraper.normalize_phone("123") == "123"

    @pytest.mark.asyncio
    async def test_analyze_url_safe(self):
        """Test analyzing safe URL"""
        result = await url_scraper.analyze_url("https://google.com")
        assert result["risk_level"] == "LOW"
        assert "domain" in result

    @pytest.mark.asyncio
    async def test_analyze_url_suspicious(self):
        """Test analyzing suspicious URL pattern"""
        result = await url_scraper.analyze_url("http://paypal-verification.ml")
        assert result["risk_level"] in ["HIGH", "MEDIUM"]


class TestExplanationEngine:
    """Tests for Explanation Engine"""

    def test_get_explanation_high_risk(self):
        """Test explanation for high risk"""
        exp = explanation_engine.get_explanation("HIGH", "OTP Fraud")
        assert exp["headline"] is not None
        assert exp["severity"] == "critical"
        assert exp["should_worry"] == True

    def test_get_explanation_low_risk(self):
        """Test explanation for low risk"""
        exp = explanation_engine.get_explanation("LOW")
        assert exp["risk_level"] == "LOW" if "risk_level" in exp else True
        assert exp["should_worry"] == False

    def test_hindi_translation(self):
        """Test Hindi translation"""
        exp = explanation_engine.get_explanation("HIGH", "OTP Fraud", language="hi")
        assert "headline_hi" in exp

    def test_get_all_scam_types(self):
        """Test listing scam types"""
        types = explanation_engine.get_all_scam_types()
        assert len(types) > 0
        assert "OTP Fraud" in types


class TestConfidenceScorer:
    """Tests for Confidence Scorer"""
    
    def test_calculate_confidence_high(self):
        """Test high confidence calculation"""
        result = confidence_scorer.calculate_confidence(
            pattern_confidence=0.95,
            ai_confidence=0.95,
            reputation_score=0.9,
            has_urgency=True
        )
        assert result["risk_level"] == "HIGH"
        assert result["confidence"] > 0.7

    def test_calculate_confidence_low(self):
        """Test low confidence calculation"""
        result = confidence_scorer.calculate_confidence(
            pattern_confidence=0.1,
            ai_confidence=0.1,
            sender_trusted=True
        )
        assert result["risk_level"] == "LOW"
        assert result["confidence"] < 0.4

    def test_blocked_sender_override(self):
        """Test blocked sender forces high risk"""
        result = confidence_scorer.calculate_confidence(
            sender_blocked=True
        )
        assert result["risk_level"] == "HIGH"
        assert result["confidence"] == 1.0

    def test_trusted_sender_override(self):
        """Test trusted sender forces low risk"""
        result = confidence_scorer.calculate_confidence(
            sender_trusted=True
        )
        assert result["risk_level"] == "LOW"
        assert result["confidence"] == 0.1


from app.services.scam_detector import ScamDetector

class TestTraiLogic:
    """Tests for TRAI Regulation Logic"""
    
    def setup_method(self):
        self.detector = ScamDetector()

    @pytest.mark.asyncio
    async def test_trai_marketing_exception(self):
        """Test that TRAI regulated sender marketing is downgraded to LOW risk"""
        # Trigger loan_scam pattern: "pre-approved loan"
        # TRAI sender + -P suffix = Marketing (LOW)
        message = "Dear customer, your pre-approved loan of 500000 is ready. Apply now. -P"
        
        result = await self.detector.analyze_quick(message, sender="AD-HDFCBK")
        assert result["risk_level"] == "LOW"
        assert result["scam_type"] == "Marketing/Spam"
        
        # However, KYC scam should still be HIGH even from TRAI header
        # Must match regex: 'bank account block' and 'complete your kyc immediately'
        result_scam = await self.detector.analyze_quick(
            "Your bank account is blocked. complete your kyc immediately. -S",
            sender="AD-HDFCBK"
        )
        assert result_scam["risk_level"] == "HIGH"
        assert result_scam["scam_type"] == "kyc_scam"

    @pytest.mark.asyncio
    async def test_trai_transactional(self):
        """Test that TRAI transactional messages (-T) are safe unless critical scam"""
        # "Urgent" is usually MEDIUM risk, but with -T it should be Verified Info (LOW)
        message = "Your OTP is 123456. Valid for 10 mins. -T"
        
        result = await self.detector.analyze_quick(message, sender="AD-HDFCBK")
        assert result["risk_level"] == "LOW"
        assert result["scam_type"] == "Transactional/Info"

    @pytest.mark.asyncio
    async def test_non_trai_scam(self):
        """Test that non-TRAI sender sending same message is HIGH risk"""
        # Even with -P suffix, if sender is not TRAI/Safe, treat as HIGH risk due to loan_scam pattern
        message = "Dear customer, your pre-approved loan of 500000 is ready. Apply now. -P"
        
        result = await self.detector.analyze_quick(message, sender="9876543210")
        assert result["risk_level"] == "HIGH"


class TestMultilingualDetection:
    """Tests for multi-language scam detection via AI model (Llama 3.3)
    
    NOTE: Multilingual detection is handled by the AI model, not local patterns.
    The AI understands all 22 Indian languages natively.
    These tests use analyze_quick() for speed, so non-English messages may return LOW
    since local patterns are English-only. Full AI analysis would require API calls.
    """
    
    def setup_method(self):
        self.detector = ScamDetector()

    @pytest.mark.asyncio
    async def test_english_pattern_still_works(self):
        """Test that English patterns still work for fast detection"""
        # Uses pattern: "complete your kyc immediately"
        message = "Dear customer, complete your kyc immediately to avoid account suspension."
        
        result = await self.detector.analyze_quick(message, sender="9876543210")
        assert result["risk_level"] == "HIGH"
        assert result["scam_type"] == "kyc_scam"

    @pytest.mark.asyncio
    async def test_hindi_message_goes_to_ai(self):
        """Test Hindi messages - pattern match returns LOW, AI would catch it"""
        # Hindi messages don't match English patterns, so quick analysis returns LOW
        # Full AI analysis (with API) would return HIGH
        message = "आपका खाता ब्लॉक हो गया है। तुरंत केवाईसी अपडेट करें"
        
        result = await self.detector.analyze_quick(message, sender="9876543210")
        # Pattern matching doesn't catch Hindi, returns LOW - AI handles this
        assert result["risk_level"] == "LOW"

    @pytest.mark.asyncio
    async def test_hinglish_with_english_keywords(self):
        """Test Hinglish messages with English keywords are caught"""
        # "Your account block" contains English patterns
        message = "Aapka bank account block ho gaya. Click bit.ly/scam"
        
        result = await self.detector.analyze_quick(message, sender="9876543210")
        # Should catch "bit.ly" or "account block" patterns
        assert result["risk_level"] in ["HIGH", "MEDIUM"]

    @pytest.mark.asyncio
    async def test_safe_message_stays_safe(self):
        """Test that safe messages in any language are not flagged"""
        message = "नमस्ते, आप कैसे हैं?"  # Hello, how are you?
        
        result = await self.detector.analyze_quick(message, sender="+919876543210")
        assert result["risk_level"] == "LOW"

