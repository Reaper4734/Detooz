"""
Firebase Cloud Messaging (FCM) Push Notification Service - V1 API

Sends push notifications to guardians when scams are detected.
Uses Firebase Admin SDK with service account credentials.
"""
import json
import os
from typing import Optional
import httpx
from google.oauth2 import service_account
from google.auth.transport.requests import Request


class FCMService:
    """Service for sending Firebase Cloud Messaging push notifications using V1 API"""
    
    def __init__(self):
        self.project_id = None
        self.credentials = None
        self._load_credentials()
    
    def _load_credentials(self):
        """Load Firebase service account credentials (Hybrid: Env Var or Local File)"""
        
        # 1. Try Environment Variable (Cloud Mode)
        env_creds = os.getenv("FIREBASE_CREDENTIALS_JSON")
        if env_creds:
            try:
                service_account_info = json.loads(env_creds)
                self.project_id = service_account_info.get('project_id')
                self.credentials = service_account.Credentials.from_service_account_info(
                    service_account_info,
                    scopes=['https://www.googleapis.com/auth/firebase.messaging']
                )
                print(f"✅ FCM Service initialized from ENV VAR with project: {self.project_id}")
                return
            except Exception as e:
                print(f"❌ Failed to parse FIREBASE_CREDENTIALS_JSON: {e}")

        # 2. Try Local File (College Project Mode)
        service_account_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            "firebase-service-account.json"
        )
        
        if os.path.exists(service_account_path):
            try:
                with open(service_account_path, 'r') as f:
                    service_account_info = json.load(f)
                    self.project_id = service_account_info.get('project_id')
                
                self.credentials = service_account.Credentials.from_service_account_file(
                    service_account_path,
                    scopes=['https://www.googleapis.com/auth/firebase.messaging']
                )
                print(f"✅ FCM Service initialized from LOCAL FILE with project: {self.project_id}")
            except Exception as e:
                print(f"❌ Failed to load Firebase credentials file: {e}")
        else:
            print("⚠️ FCM credentials not found (Env Var or File). Push notifications disabled.")
    
    def _get_access_token(self) -> Optional[str]:
        """Get a valid access token, refreshing if necessary"""
        if not self.credentials:
            return None
        
        try:
            if not self.credentials.valid:
                self.credentials.refresh(Request())
            return self.credentials.token
        except Exception as e:
            print(f"❌ Failed to get FCM access token: {e}")
            return None
    
    async def send_guardian_alert(
        self,
        fcm_token: str,
        protected_user_name: str,
        scam_type: str,
        sender: str,
        message_preview: str,
        alert_id: int,
        risk_level: str = "HIGH"
    ) -> bool:
        """
        Send push notification to guardian about a scam alert using FCM V1 API.
        """
        if not self.project_id or not self.credentials:
            print("⚠️ FCM not configured. Push notification skipped.")
            return False
        
        if not fcm_token:
            print("⚠️ No FCM token provided")
            return False
        
        access_token = self._get_access_token()
        if not access_token:
            return False
        
        # FCM V1 API endpoint
        url = f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send"
        
        # Build notification payload (FCM V1 format)
        payload = {
            "message": {
                "token": fcm_token,
                "notification": {
                    "title": f"🚨 SCAM ALERT: {protected_user_name}",
                    "body": f"{scam_type} detected from {sender}"
                },
                "data": {
                    "type": "guardian_alert",
                    "alert_id": str(alert_id),
                    "user_name": protected_user_name,
                    "scam_type": scam_type,
                    "sender": sender,
                    "message_preview": message_preview[:100] if len(message_preview) > 100 else message_preview,
                    "risk_level": risk_level,
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                },
                "android": {
                    "priority": "HIGH",
                    "notification": {
                        "channel_id": "guardian_alerts",
                        "sound": "default",
                        "default_vibrate_timings": True,
                        "visibility": "PUBLIC",
                        "notification_priority": "PRIORITY_MAX"
                    }
                }
            }
        }
        
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    url,
                    json=payload,
                    headers=headers,
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    print(f"✅ FCM push sent to guardian for alert #{alert_id}")
                    return True
                else:
                    print(f"❌ FCM push failed: {response.status_code} - {response.text}")
                    return False
                    
        except Exception as e:
            print(f"❌ FCM push error: {e}")
            return False
    
    async def send_notification(
        self,
        fcm_token: str,
        title: str,
        body: str,
        data: Optional[dict] = None
    ) -> bool:
        """Send a generic push notification"""
        if not self.project_id or not self.credentials or not fcm_token:
            return False
        
        access_token = self._get_access_token()
        if not access_token:
            return False
        
        url = f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send"
        
        payload = {
            "message": {
                "token": fcm_token,
                "notification": {
                    "title": title,
                    "body": body
                },
                "data": data or {},
                "android": {
                    "priority": "HIGH"
                }
            }
        }
        
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    url,
                    json=payload,
                    headers=headers,
                    timeout=10.0
                )
                return response.status_code == 200
        except Exception as e:
            print(f"FCM error: {e}")
            return False


# Singleton instance
fcm_service = FCMService()
