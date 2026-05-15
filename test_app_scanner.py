import asyncio
import sys
import os
from unittest.mock import AsyncMock, MagicMock

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "backend")))

from app.routers.scan import scan_app
from app.schemas import AppScanRequest
from app.models import User

async def run_test():
    print("--- 🚀 Starting Backend App Scanner Test ---\n")
    
    # 1. Setup Mock User
    mock_user = User(id=1, email="test@example.com")
    
    # 2. Setup Mock DB Session
    mock_db = AsyncMock()
    
    # 3. Create a Dummy Malicious Request (Simulating an older person downloading a fake AnyDesk)
    request = AppScanRequest(
        package_name="com.dev.fake.anydesk.support",
        app_name="AnyDesk Remote Support",
        signature_sha256="A1B2C3D4E5F6",
        requested_permissions=["android.permission.BIND_ACCESSIBILITY_SERVICE", "android.permission.RECEIVE_SMS"]
    )
    
    print(f"📦 Simulating install of: {request.app_name} ({request.package_name})")
    
    # 4. We need to mock the detector so we don't actually hit external LLMs for a quick test
    # We will temporarily patch the detector in the scan router
    import app.routers.scan as scan_router
    original_detector = scan_router.detector
    
    mock_detector = AsyncMock()
    mock_detector.analyze.return_value = {
        "risk_level": "HIGH",
        "reason": "App impersonates AnyDesk and requests highly dangerous Accessibility and SMS permissions. Package name is non-official.",
        "confidence": 0.98
    }
    scan_router.detector = mock_detector
    
    # Mock guardian alert service to avoid DB crashes during test
    scan_router.guardian_alert_service = AsyncMock()
    
    # 5. Execute Function!
    try:
        response = await scan_app(request=request, db=mock_db, current_user=mock_user)
        
        print("\n✅ TEST PASSED: Endpoint returned successfully!")
        print("--- 🔍 Analysis Results ---")
        print(f"Is Malicious: {response.is_malicious}")
        print(f"Risk Level: {response.risk_level}")
        print(f"Reason: {response.reason}")
        print(f"Play Store Verified: {response.play_store_verified}")
        
        # Verify Guardian Alert was triggered
        scan_router.guardian_alert_service.create_alerts_for_scan.assert_called_once()
        print("🛡️ Guardian Alert Service was SUCCESSFULLY triggered to notify family members!")
        
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
    finally:
        # Restore mocks
        scan_router.detector = original_detector

if __name__ == "__main__":
    asyncio.run(run_test())
