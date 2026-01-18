"""
Guardian Tests
Tests for /api/guardian endpoints
"""
import pytest
from httpx import AsyncClient


class TestGuardianEndpoints:
    """Tests for guardian management"""

    @pytest.mark.asyncio
    async def test_list_guardians_empty(self, authenticated_client: AsyncClient):
        """Test listing guardians when empty"""
        response = await authenticated_client.get("/api/guardian/list")
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_add_guardian(self, authenticated_client: AsyncClient):
        """Test adding a guardian"""
        response = await authenticated_client.post(
            "/api/guardian/add",
            json={
                "name": "Mom",
                "phone": "+919876543210"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Mom"
        assert data["phone"] == "+919876543210"
        assert "id" in data

    @pytest.mark.asyncio
    async def test_add_guardian_with_telegram(self, authenticated_client: AsyncClient):
        """Test adding guardian with Telegram"""
        response = await authenticated_client.post(
            "/api/guardian/add",
            json={
                "name": "Dad",
                "phone": "+911234567890",
                "telegram_chat_id": "123456789"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["telegram_chat_id"] == "123456789"

    @pytest.mark.asyncio
    async def test_list_guardians_after_add(self, authenticated_client: AsyncClient):
        """Test listing guardians after adding"""
        # Add guardian
        await authenticated_client.post(
            "/api/guardian/add",
            json={"name": "Brother", "phone": "+919999999999"}
        )
        
        response = await authenticated_client.get("/api/guardian/list")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1

    @pytest.mark.asyncio
    async def test_update_guardian(self, authenticated_client: AsyncClient):
        """Test updating a guardian"""
        # Add first
        add_response = await authenticated_client.post(
            "/api/guardian/add",
            json={"name": "Sister", "phone": "+918888888888"}
        )
        guardian_id = add_response.json()["id"]
        
        # Update
        response = await authenticated_client.put(
            f"/api/guardian/{guardian_id}",
            json={"name": "Sister Updated", "phone": "+918888888888"}
        )
        assert response.status_code == 200
        assert response.json()["name"] == "Sister Updated"

    @pytest.mark.asyncio
    async def test_delete_guardian(self, authenticated_client: AsyncClient):
        """Test deleting a guardian"""
        # Add first
        add_response = await authenticated_client.post(
            "/api/guardian/add",
            json={"name": "Uncle", "phone": "+917777777777"}
        )
        guardian_id = add_response.json()["id"]
        
        # Delete
        response = await authenticated_client.delete(f"/api/guardian/{guardian_id}")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_delete_nonexistent_guardian(self, authenticated_client: AsyncClient):
        """Test deleting non-existent guardian"""
        response = await authenticated_client.delete("/api/guardian/99999")
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_guardian_no_auth(self, client: AsyncClient):
        """Test guardian endpoints require authentication"""
        response = await client.get("/api/guardian/list")
        assert response.status_code == 401
