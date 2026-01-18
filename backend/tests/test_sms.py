"""
SMS Analysis Tests
Tests for /api/sms endpoints
"""
import pytest
from httpx import AsyncClient


class TestSmsAnalysisEndpoints:
    """Tests for SMS analysis"""

    @pytest.mark.asyncio
    async def test_analyze_sms_safe(self, authenticated_client: AsyncClient):
        """Test analyzing safe SMS"""
        response = await authenticated_client.post(
            "/api/sms/analyze",
            json={
                "sender": "+919876543210",
                "message": "Hi, how are you doing today?",
                "timestamp": "2026-01-17T10:00:00Z"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "risk_level" in data
        assert "confidence" in data

    @pytest.mark.asyncio
    async def test_analyze_sms_scam_patterns(self, authenticated_client: AsyncClient):
        """Test analyzing SMS with scam patterns"""
        response = await authenticated_client.post(
            "/api/sms/analyze",
            json={
                "sender": "UNKNOWN",
                "message": "Your bank account has been suspended! Click here immediately: bit.ly/scam123",
                "timestamp": "2026-01-17T10:00:00Z"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["risk_level"] in ["HIGH", "MEDIUM"]

    @pytest.mark.asyncio
    async def test_analyze_sms_creates_scan(self, authenticated_client: AsyncClient):
        """Test that SMS analysis creates a scan record"""
        response = await authenticated_client.post(
            "/api/sms/analyze",
            json={
                "sender": "+911234567890",
                "message": "Test message",
                "timestamp": "2026-01-17T10:00:00Z"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "scan_id" in data

    @pytest.mark.asyncio
    async def test_get_recent_sms(self, authenticated_client: AsyncClient):
        """Test getting recent SMS scans"""
        # First add a scan
        await authenticated_client.post(
            "/api/sms/analyze",
            json={
                "sender": "+919999999999",
                "message": "Test for recent",
                "timestamp": "2026-01-17T10:00:00Z"
            }
        )
        
        response = await authenticated_client.get("/api/sms/recent")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_get_recent_sms_with_limit(self, authenticated_client: AsyncClient):
        """Test recent SMS with limit"""
        response = await authenticated_client.get("/api/sms/recent?limit=5")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_block_sender(self, authenticated_client: AsyncClient):
        """Test blocking a sender"""
        # First analyze a message
        await authenticated_client.post(
            "/api/sms/analyze",
            json={
                "sender": "+918888888888",
                "message": "Scam message",
                "timestamp": "2026-01-17T10:00:00Z"
            }
        )
        
        response = await authenticated_client.post("/api/sms/block/+918888888888")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_unblock_sender(self, authenticated_client: AsyncClient):
        """Test unblocking a sender"""
        # Block first
        await authenticated_client.post("/api/sms/block/+917777777777")
        
        # Unblock
        response = await authenticated_client.delete("/api/sms/block/+917777777777")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_get_blocked_senders(self, authenticated_client: AsyncClient):
        """Test getting blocked senders list"""
        response = await authenticated_client.get("/api/sms/blocked")
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    @pytest.mark.asyncio
    async def test_get_sms_stats(self, authenticated_client: AsyncClient):
        """Test getting SMS statistics"""
        response = await authenticated_client.get("/api/sms/stats")
        assert response.status_code == 200
        data = response.json()
        assert "total_scans" in data

    @pytest.mark.asyncio
    async def test_sms_no_auth(self, client: AsyncClient):
        """Test SMS endpoints require authentication"""
        response = await client.post(
            "/api/sms/analyze",
            json={
                "sender": "+919876543210",
                "message": "Test",
                "timestamp": "2026-01-17T10:00:00Z"
            }
        )
        assert response.status_code == 401
