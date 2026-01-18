"""
Feedback Tests
Tests for /api/feedback endpoints
"""
import pytest
from httpx import AsyncClient
from app.models import Scan, PlatformType, RiskLevel


class TestFeedbackEndpoints:
    """Tests for feedback collection"""

    @pytest.fixture
    async def test_scan(self, db_session, test_user):
        """Create a test scan for feedback"""
        scan = Scan(
            user_id=test_user.id,
            sender="+919876543210",
            message="Test message for feedback",
            message_preview="Test message for feedback",
            platform=PlatformType.SMS,
            risk_level=RiskLevel.HIGH,
            risk_reason="Test reason",
            scam_type="Test Scam",
            confidence=0.9
        )
        db_session.add(scan)
        await db_session.commit()
        await db_session.refresh(scan)
        return scan

    @pytest.mark.asyncio
    async def test_submit_feedback_safe(self, authenticated_client: AsyncClient, test_scan):
        """Test submitting feedback marking scan as safe"""
        response = await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={
                "user_verdict": "safe",
                "comment": "I know this sender"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["user_verdict"] == "safe"
        assert data["scan_id"] == test_scan.id

    @pytest.mark.asyncio
    async def test_submit_feedback_scam(self, authenticated_client: AsyncClient, test_scan):
        """Test submitting feedback confirming scam"""
        response = await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={
                "user_verdict": "scam"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["user_verdict"] == "scam"

    @pytest.mark.asyncio
    async def test_submit_feedback_unsure(self, authenticated_client: AsyncClient, test_scan):
        """Test submitting feedback as unsure"""
        response = await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={
                "user_verdict": "unsure"
            }
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_submit_feedback_invalid_verdict(self, authenticated_client: AsyncClient, test_scan):
        """Test submitting invalid verdict"""
        response = await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={
                "user_verdict": "maybe"  # Invalid
            }
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_submit_feedback_duplicate(self, authenticated_client: AsyncClient, test_scan):
        """Test submitting feedback twice fails"""
        # First submission
        await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={"user_verdict": "safe"}
        )
        
        # Second submission should fail
        response = await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={"user_verdict": "scam"}
        )
        assert response.status_code == 400
        assert "already" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_submit_feedback_nonexistent_scan(self, authenticated_client: AsyncClient):
        """Test submitting feedback for non-existent scan"""
        response = await authenticated_client.post(
            "/api/feedback/scan/99999",
            json={"user_verdict": "safe"}
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_get_my_feedback_empty(self, authenticated_client: AsyncClient):
        """Test getting feedback when none submitted"""
        response = await authenticated_client.get("/api/feedback/my-feedback")
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_get_my_feedback_after_submit(self, authenticated_client: AsyncClient, test_scan):
        """Test getting feedback after submission"""
        # Submit feedback
        await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={"user_verdict": "safe", "comment": "Test comment"}
        )
        
        # Get feedback
        response = await authenticated_client.get("/api/feedback/my-feedback")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert data[0]["user_verdict"] == "safe"

    @pytest.mark.asyncio
    async def test_get_feedback_stats(self, authenticated_client: AsyncClient):
        """Test getting feedback statistics"""
        response = await authenticated_client.get("/api/feedback/stats")
        assert response.status_code == 200
        data = response.json()
        assert "total_feedback" in data
        assert "agreement_rate" in data

    @pytest.mark.asyncio
    async def test_delete_feedback(self, authenticated_client: AsyncClient, test_scan):
        """Test deleting feedback"""
        # Submit first
        await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={"user_verdict": "safe"}
        )
        
        # Delete
        response = await authenticated_client.delete(f"/api/feedback/scan/{test_scan.id}")
        assert response.status_code == 200
        
        # Can submit again after deletion
        response = await authenticated_client.post(
            f"/api/feedback/scan/{test_scan.id}",
            json={"user_verdict": "scam"}
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_feedback_no_auth(self, client: AsyncClient):
        """Test feedback requires authentication"""
        response = await client.get("/api/feedback/stats")
        assert response.status_code == 401
