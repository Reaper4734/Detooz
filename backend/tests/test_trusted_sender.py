"""
Trusted Sender Tests
Tests for /api/trusted endpoints
"""
import pytest
from httpx import AsyncClient


class TestTrustedSenderEndpoints:
    """Tests for trusted sender management"""

    @pytest.mark.asyncio
    async def test_list_trusted_empty(self, authenticated_client: AsyncClient):
        """Test listing trusted senders when empty"""
        response = await authenticated_client.get("/api/trusted/list")
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_add_trusted_sender(self, authenticated_client: AsyncClient):
        """Test adding a trusted sender"""
        response = await authenticated_client.post(
            "/api/trusted/add",
            json={
                "sender": "+919876543210",
                "name": "Mom",
                "reason": "Family member"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["sender"] == "+919876543210"
        assert data["name"] == "Mom"
        assert "id" in data

    @pytest.mark.asyncio
    async def test_add_trusted_sender_minimal(self, authenticated_client: AsyncClient):
        """Test adding trusted sender with only sender field"""
        response = await authenticated_client.post(
            "/api/trusted/add",
            json={"sender": "+911234567890"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["sender"] == "+911234567890"

    @pytest.mark.asyncio
    async def test_add_duplicate_trusted_sender(self, authenticated_client: AsyncClient):
        """Test adding same sender twice fails"""
        # Add first time
        await authenticated_client.post(
            "/api/trusted/add",
            json={"sender": "+919111111111"}
        )
        # Add same sender again
        response = await authenticated_client.post(
            "/api/trusted/add",
            json={"sender": "+919111111111"}
        )
        assert response.status_code == 400
        assert "already" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_list_trusted_after_adding(self, authenticated_client: AsyncClient):
        """Test listing shows added senders"""
        # Add a sender
        await authenticated_client.post(
            "/api/trusted/add",
            json={"sender": "+919999999999", "name": "Friend"}
        )
        
        # List should contain the sender
        response = await authenticated_client.get("/api/trusted/list")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert any(s["sender"] == "+919999999999" for s in data)

    @pytest.mark.asyncio
    async def test_check_trusted_sender_exists(self, authenticated_client: AsyncClient):
        """Test checking if trusted sender exists"""
        # Add sender
        await authenticated_client.post(
            "/api/trusted/add",
            json={"sender": "+918888888888"}
        )
        
        # Check
        response = await authenticated_client.get("/api/trusted/check/+918888888888")
        assert response.status_code == 200
        data = response.json()
        assert data["is_trusted"] == True

    @pytest.mark.asyncio
    async def test_check_trusted_sender_not_exists(self, authenticated_client: AsyncClient):
        """Test checking non-existent trusted sender"""
        response = await authenticated_client.get("/api/trusted/check/+910000000000")
        assert response.status_code == 200
        data = response.json()
        assert data["is_trusted"] == False

    @pytest.mark.asyncio
    async def test_remove_trusted_sender(self, authenticated_client: AsyncClient):
        """Test removing a trusted sender"""
        # Add sender first
        await authenticated_client.post(
            "/api/trusted/add",
            json={"sender": "+917777777777"}
        )
        
        # Remove
        response = await authenticated_client.delete("/api/trusted/+917777777777")
        assert response.status_code == 200
        
        # Verify removed
        check_response = await authenticated_client.get("/api/trusted/check/+917777777777")
        assert check_response.json()["is_trusted"] == False

    @pytest.mark.asyncio
    async def test_remove_nonexistent_sender(self, authenticated_client: AsyncClient):
        """Test removing non-existent sender"""
        response = await authenticated_client.delete("/api/trusted/+910123456789")
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_trusted_no_auth(self, client: AsyncClient):
        """Test trusted endpoints require authentication"""
        response = await client.get("/api/trusted/list")
        assert response.status_code == 401
