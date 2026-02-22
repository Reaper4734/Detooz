"""
Guardian Link Tests
Tests for /api/guardian-link endpoints (OTP-based guardian linking system)
"""
import pytest
from httpx import AsyncClient


class TestGuardianLinkEndpoints:
    """Tests for guardian linking functionality"""

    @pytest.mark.asyncio
    async def test_my_guardians_empty(self, authenticated_client: AsyncClient):
        """Test listing guardians when none linked"""
        response = await authenticated_client.get("/api/guardian-link/my-guardians")
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_my_protected_users_empty(self, authenticated_client: AsyncClient):
        """Test listing protected users when none linked"""
        response = await authenticated_client.get("/api/guardian-link/my-protected-users")
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_generate_otp(self, authenticated_client: AsyncClient):
        """Test generating an OTP for guardian linking"""
        response = await authenticated_client.post(
            "/api/guardian-link/generate-otp",
            json={
                "guardian_email": "guardian@test.com"
            }
        )
        # Should return 200 with OTP details (or 404 if guardian not registered)
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_guardian_link_no_auth(self, client: AsyncClient):
        """Test guardian endpoints require authentication"""
        response = await client.get("/api/guardian-link/my-guardians")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_my_protected_users_no_auth(self, client: AsyncClient):
        """Test protected users endpoint requires authentication"""
        response = await client.get("/api/guardian-link/my-protected-users")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_verify_otp_invalid(self, authenticated_client: AsyncClient):
        """Test verifying an invalid OTP"""
        response = await authenticated_client.post(
            "/api/guardian-link/verify-otp",
            json={
                "otp": "000000",
                "user_email": "test@example.com"
            }
        )
        # Should fail with invalid OTP
        assert response.status_code in [400, 404, 422]

    @pytest.mark.asyncio
    async def test_revoke_nonexistent_link(self, authenticated_client: AsyncClient):
        """Test revoking a non-existent guardian link"""
        response = await authenticated_client.delete("/api/guardian-link/revoke/99999")
        assert response.status_code == 404
