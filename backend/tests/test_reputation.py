"""
Reputation Database Tests
Tests for /api/reputation endpoints
"""
import pytest
from httpx import AsyncClient


class TestReputationEndpoints:
    """Tests for reputation database"""

    @pytest.mark.asyncio
    async def test_check_phone_clean(self, authenticated_client: AsyncClient):
        """Test checking phone with no reports"""
        response = await authenticated_client.get(
            "/api/reputation/check",
            params={"phone": "+919876543210"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["is_blacklisted"] == False
        assert data["risk_score"] == 0.0

    @pytest.mark.asyncio
    async def test_check_url_clean(self, authenticated_client: AsyncClient):
        """Test checking URL with no reports"""
        response = await authenticated_client.get(
            "/api/reputation/check",
            params={"url": "https://google.com"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["is_blacklisted"] == False

    @pytest.mark.asyncio
    async def test_check_no_params(self, authenticated_client: AsyncClient):
        """Test checking with no parameters fails"""
        response = await authenticated_client.get("/api/reputation/check")
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_report_scam_phone(self, authenticated_client: AsyncClient):
        """Test reporting scam phone number"""
        response = await authenticated_client.post(
            "/api/reputation/report",
            json={
                "value": "+911111111111",
                "type": "phone",
                "reason": "Fake KYC call"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["reports_count"] == 1

    @pytest.mark.asyncio
    async def test_report_scam_url(self, authenticated_client: AsyncClient):
        """Test reporting scam URL"""
        response = await authenticated_client.post(
            "/api/reputation/report",
            json={
                "value": "http://fake-bank.com/login",
                "type": "url"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["reports_count"] == 1

    @pytest.mark.asyncio
    async def test_report_scam_domain(self, authenticated_client: AsyncClient):
        """Test reporting scam domain"""
        response = await authenticated_client.post(
            "/api/reputation/report",
            json={
                "value": "fake-bank.com",
                "type": "domain"
            }
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_report_invalid_type(self, authenticated_client: AsyncClient):
        """Test reporting with invalid type"""
        response = await authenticated_client.post(
            "/api/reputation/report",
            json={
                "value": "something",
                "type": "invalid"
            }
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_report_increments_count(self, authenticated_client: AsyncClient):
        """Test multiple reports increment count"""
        # First report
        response1 = await authenticated_client.post(
            "/api/reputation/report",
            json={"value": "+912222222222", "type": "phone"}
        )
        assert response1.json()["reports_count"] == 1
        
        # Second report
        response2 = await authenticated_client.post(
            "/api/reputation/report",
            json={"value": "+912222222222", "type": "phone"}
        )
        assert response2.json()["reports_count"] == 2

    @pytest.mark.asyncio
    async def test_check_after_report(self, authenticated_client: AsyncClient):
        """Test checking shows reported item"""
        # Report
        await authenticated_client.post(
            "/api/reputation/report",
            json={"value": "+913333333333", "type": "phone"}
        )
        
        # Check
        response = await authenticated_client.get(
            "/api/reputation/check",
            params={"phone": "+913333333333"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["is_blacklisted"] == True
        assert data["reports_count"] >= 1
        assert data["risk_score"] > 0

    @pytest.mark.asyncio
    async def test_get_recent_reports(self, authenticated_client: AsyncClient):
        """Test getting recent reports"""
        # Add some reports
        await authenticated_client.post(
            "/api/reputation/report",
            json={"value": "+914444444444", "type": "phone"}
        )
        
        response = await authenticated_client.get("/api/reputation/recent")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_get_recent_filtered_by_type(self, authenticated_client: AsyncClient):
        """Test getting recent reports filtered by type"""
        response = await authenticated_client.get(
            "/api/reputation/recent",
            params={"type": "phone"}
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_get_verified_scams(self, authenticated_client: AsyncClient):
        """Test getting verified scams"""
        response = await authenticated_client.get("/api/reputation/verified")
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    @pytest.mark.asyncio
    async def test_reputation_no_auth(self, client: AsyncClient):
        """Test reputation requires authentication"""
        response = await client.get(
            "/api/reputation/check",
            params={"phone": "+919876543210"}
        )
        assert response.status_code == 401
