"""
User Stats and Settings Tests
Tests for /api/user endpoints
"""
import pytest
from httpx import AsyncClient


class TestUserStatsEndpoints:
    """Tests for user statistics"""

    @pytest.mark.asyncio
    async def test_get_user_stats(self, authenticated_client: AsyncClient):
        """Test getting user statistics"""
        response = await authenticated_client.get("/api/user/stats")
        assert response.status_code == 200
        data = response.json()
        
        # Check all expected fields exist
        assert "total_scans" in data
        assert "high_risk_blocked" in data
        assert "medium_risk_detected" in data
        assert "low_risk_safe" in data
        assert "protection_score" in data

    @pytest.mark.asyncio
    async def test_stats_no_auth(self, client: AsyncClient):
        """Test stats require authentication"""
        response = await client.get("/api/user/stats")
        assert response.status_code == 401


class TestUserSettingsEndpoints:
    """Tests for user settings"""

    @pytest.mark.asyncio
    async def test_get_settings_default(self, authenticated_client: AsyncClient):
        """Test getting default settings"""
        response = await authenticated_client.get("/api/user/settings")
        assert response.status_code == 200
        data = response.json()
        
        # Check default values
        assert data["language"] == "en"
        assert data["auto_block_high_risk"] == True
        assert data["alert_guardians_threshold"] == "HIGH"
        assert data["receive_tips"] == True

    @pytest.mark.asyncio
    async def test_update_settings_partial(self, authenticated_client: AsyncClient):
        """Test updating partial settings"""
        response = await authenticated_client.put(
            "/api/user/settings",
            json={"language": "hi"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["language"] == "hi"
        # Other settings should remain default
        assert data["auto_block_high_risk"] == True

    @pytest.mark.asyncio
    async def test_update_settings_full(self, authenticated_client: AsyncClient):
        """Test updating all settings"""
        response = await authenticated_client.put(
            "/api/user/settings",
            json={
                "language": "hi",
                "auto_block_high_risk": False,
                "alert_guardians_threshold": "MEDIUM",
                "receive_tips": False
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["language"] == "hi"
        assert data["auto_block_high_risk"] == False
        assert data["alert_guardians_threshold"] == "MEDIUM"
        assert data["receive_tips"] == False

    @pytest.mark.asyncio
    async def test_update_settings_invalid_threshold(self, authenticated_client: AsyncClient):
        """Test updating with invalid threshold"""
        response = await authenticated_client.put(
            "/api/user/settings",
            json={"alert_guardians_threshold": "INVALID"}
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_set_language_english(self, authenticated_client: AsyncClient):
        """Test setting language to English"""
        response = await authenticated_client.put("/api/user/language/en")
        assert response.status_code == 200
        
        # Verify
        settings = await authenticated_client.get("/api/user/settings")
        assert settings.json()["language"] == "en"

    @pytest.mark.asyncio
    async def test_set_language_hindi(self, authenticated_client: AsyncClient):
        """Test setting language to Hindi"""
        response = await authenticated_client.put("/api/user/language/hi")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_set_language_invalid(self, authenticated_client: AsyncClient):
        """Test setting invalid language"""
        response = await authenticated_client.put("/api/user/language/invalid")
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_settings_no_auth(self, client: AsyncClient):
        """Test settings require authentication"""
        response = await client.get("/api/user/settings")
        assert response.status_code == 401
