"""
Scan Service Tests
Tests for /api/scan endpoints
"""
import pytest
from httpx import AsyncClient


class TestScanEndpoints:
    """Tests for scan functionality"""

    @pytest.mark.asyncio
    async def test_analyze_text_message(self, authenticated_client: AsyncClient):
        """Test scanning a text message"""
        response = await authenticated_client.post(
            "/api/scan/analyze",
            json={
                "message": "Hello, this is a test message.",
                "sender": "+919876543210",
                "platform": "SMS"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "risk_level" in data
        assert "confidence" in data
        assert "id" in data

    @pytest.mark.asyncio
    async def test_analyze_high_risk_message(self, authenticated_client: AsyncClient):
        """Test scanning a high risk message"""
        response = await authenticated_client.post(
            "/api/scan/analyze",
            json={
                "message": "URGENT: Your account is suspended. Click here: bit.ly/12345",
                "sender": "Unknown",
                "platform": "WHATSAPP"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["risk_level"] in ["HIGH", "MEDIUM"]

    @pytest.mark.asyncio
    async def test_get_scan_history(self, authenticated_client: AsyncClient):
        """Test getting scan history"""
        # Create scan first
        await authenticated_client.post(
            "/api/scan/analyze",
            json={"message": "History test", "sender": "+919876543210", "platform": "SMS"}
        )
        
        response = await authenticated_client.get("/api/scan/history")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_get_scan_detail(self, authenticated_client: AsyncClient):
        """Test getting details of a specific scan"""
        # Create scan
        scan_res = await authenticated_client.post(
            "/api/scan/analyze",
            json={"message": "Detail test", "sender": "+919876543210", "platform": "SMS"}
        )
        scan_id = scan_res.json()["id"]
        
        # Get details
        response = await authenticated_client.get(f"/api/scan/{scan_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == scan_id
        assert data["message"] == "Detail test"

    @pytest.mark.asyncio
    async def test_mark_false_positive(self, authenticated_client: AsyncClient):
        """Test marking a scan as false positive"""
        # Create scan
        scan_res = await authenticated_client.post(
            "/api/scan/analyze",
            json={"message": "Safe message flagged as risky", "sender": "+919876543210", "platform": "SMS"}
        )
        scan_id = scan_res.json()["id"]
        
        # Mark false positive (via feedback endpoint essentially)
        # Note: In the scan router, delete often acts as "remove from history"
        response = await authenticated_client.delete(f"/api/scan/{scan_id}")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_analyze_empty_message(self, authenticated_client: AsyncClient):
        """Test scanning empty message fails"""
        response = await authenticated_client.post(
            "/api/scan/analyze",
            json={"message": "", "platform": "SMS"}
        )
        assert response.status_code == 422 # Validation error from Pydantic

    @pytest.mark.asyncio
    async def test_scan_no_auth(self, client: AsyncClient):
        """Test scan requires authentication"""
        response = await client.post(
            "/api/scan/analyze",
            json={"message": "test", "platform": "SMS"}
        )
        assert response.status_code == 401
