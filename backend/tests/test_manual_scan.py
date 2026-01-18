"""
Manual Scan Tests
Tests for /api/manual endpoints
"""
import pytest
from httpx import AsyncClient


class TestManualScanEndpoints:
    """Tests for manual scan functionality"""

    @pytest.mark.asyncio
    async def test_analyze_text(self, authenticated_client: AsyncClient):
        """Test analyzing plain text"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "You have won $1,000,000! Click here to claim now!",
                "content_type": "text"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "risk_level" in data
        assert "confidence" in data
        assert "explanation" in data
        assert data["content_type"] == "text"

    @pytest.mark.asyncio
    async def test_analyze_url(self, authenticated_client: AsyncClient):
        """Test analyzing a URL"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "https://google.com",
                "content_type": "url"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["content_type"] == "url"
        assert data["risk_level"] == "LOW"  # Google is safe

    @pytest.mark.asyncio
    async def test_analyze_suspicious_url(self, authenticated_client: AsyncClient):
        """Test analyzing suspicious URL"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "http://paypal123.tk/login",
                "content_type": "url"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["risk_level"] in ["HIGH", "MEDIUM"]

    @pytest.mark.asyncio
    async def test_analyze_phone(self, authenticated_client: AsyncClient):
        """Test analyzing phone number"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "+919876543210",
                "content_type": "phone"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["content_type"] == "phone"

    @pytest.mark.asyncio
    async def test_analyze_auto_detect_url(self, authenticated_client: AsyncClient):
        """Test auto-detection of URL"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "https://example.com/page",
                "content_type": "auto"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["content_type"] == "url"

    @pytest.mark.asyncio
    async def test_analyze_auto_detect_phone(self, authenticated_client: AsyncClient):
        """Test auto-detection of phone"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "9876543210",
                "content_type": "auto"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["content_type"] == "phone"

    @pytest.mark.asyncio
    async def test_analyze_auto_detect_text(self, authenticated_client: AsyncClient):
        """Test auto-detection defaults to text"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "This is just a normal message",
                "content_type": "auto"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["content_type"] == "text"

    @pytest.mark.asyncio
    async def test_analyze_empty_content(self, authenticated_client: AsyncClient):
        """Test analyzing empty content fails"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "",
                "content_type": "auto"
            }
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_analyze_creates_scan_record(self, authenticated_client: AsyncClient):
        """Test that analysis creates a scan record"""
        response = await authenticated_client.post(
            "/api/manual/analyze",
            json={
                "content": "Test message",
                "content_type": "text"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "scan_id" in data
        assert data["scan_id"] is not None


class TestExplanationEndpoints:
    """Tests for explanation endpoints"""

    @pytest.mark.asyncio
    async def test_get_explanation_high_risk(self, authenticated_client: AsyncClient):
        """Test getting explanation for high risk"""
        response = await authenticated_client.post(
            "/api/manual/explain",
            json={
                "risk_level": "HIGH",
                "scam_type": "OTP Fraud"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "headline" in data
        assert "details" in data
        assert "action" in data
        assert data["should_worry"] == True

    @pytest.mark.asyncio
    async def test_get_explanation_low_risk(self, authenticated_client: AsyncClient):
        """Test getting explanation for low risk"""
        response = await authenticated_client.post(
            "/api/manual/explain",
            json={
                "risk_level": "LOW"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["should_worry"] == False

    @pytest.mark.asyncio
    async def test_get_explanation_with_hindi(self, authenticated_client: AsyncClient):
        """Test getting explanation with Hindi translation"""
        response = await authenticated_client.post(
            "/api/manual/explain",
            json={
                "risk_level": "HIGH",
                "scam_type": "OTP Fraud",
                "language": "hi"
            }
        )
        assert response.status_code == 200
        data = response.json()
        # Hindi translation may or may not be present
        assert "headline" in data

    @pytest.mark.asyncio
    async def test_get_scam_types(self, authenticated_client: AsyncClient):
        """Test getting list of scam types"""
        response = await authenticated_client.get("/api/manual/scam-types")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 10  # We have 12 scam types
        
        # Check structure
        for scam_type in data:
            assert "type" in scam_type
            assert "headline" in scam_type
            assert "severity" in scam_type


class TestUrlAnalysisEndpoint:
    """Tests for URL-specific analysis"""

    @pytest.mark.asyncio
    async def test_analyze_url_safe_domain(self, authenticated_client: AsyncClient):
        """Test analyzing known safe domain"""
        response = await authenticated_client.post(
            "/api/manual/analyze-url",
            params={"url": "https://google.com"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["risk_level"] == "LOW"

    @pytest.mark.asyncio
    async def test_analyze_url_suspicious_pattern(self, authenticated_client: AsyncClient):
        """Test analyzing URL with suspicious pattern"""
        response = await authenticated_client.post(
            "/api/manual/analyze-url",
            params={"url": "http://amazon123.ml/login"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["risk_level"] in ["HIGH", "MEDIUM"]


class TestPhoneCheckEndpoint:
    """Tests for phone-specific check"""

    @pytest.mark.asyncio
    async def test_check_phone_clean(self, authenticated_client: AsyncClient):
        """Test checking clean phone"""
        response = await authenticated_client.post(
            "/api/manual/check-phone",
            params={"phone": "+919876543210"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "normalized" in data
        assert "risk_level" in data

    @pytest.mark.asyncio
    async def test_check_phone_normalization(self, authenticated_client: AsyncClient):
        """Test phone normalization"""
        response = await authenticated_client.post(
            "/api/manual/check-phone",
            params={"phone": "9876543210"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["normalized"].startswith("+91")

    @pytest.mark.asyncio
    async def test_manual_scan_no_auth(self, client: AsyncClient):
        """Test manual scan requires authentication"""
        response = await client.post(
            "/api/manual/analyze",
            json={"content": "test", "content_type": "text"}
        )
        assert response.status_code == 401
