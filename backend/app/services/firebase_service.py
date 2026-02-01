"""
Firebase Service for Phone OTP Authentication
Uses Firebase Phone Auth - FREE (10k verifications/month)
"""
import logging
from typing import Optional, Dict
import os

logger = logging.getLogger(__name__)

# Firebase Admin SDK (lazy initialization)
_firebase_app = None


def _init_firebase():
    """Initialize Firebase Admin SDK"""
    global _firebase_app
    
    if _firebase_app is not None:
        return _firebase_app
    
    try:
        import firebase_admin
        from firebase_admin import credentials
        
        # Check for service account file
        cred_path = os.getenv(
            'FIREBASE_SERVICE_ACCOUNT',
            'firebase-service-account.json'
        )
        
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized")
        else:
            logger.warning(f"Firebase service account not found: {cred_path}")
            return None
            
    except ImportError:
        logger.warning("firebase-admin package not installed")
        return None
    except Exception as e:
        logger.error(f"Firebase initialization error: {e}")
        return None
    
    return _firebase_app


class FirebaseService:
    """Service for verifying Firebase Phone Auth tokens"""
    
    @staticmethod
    def verify_id_token(id_token: str) -> Optional[Dict]:
        """
        Verify Firebase ID token and extract user info
        
        Args:
            id_token: Firebase ID token from client
            
        Returns:
            Dict with user info: {uid, phone_number, email} or None if invalid
        """
        if not _init_firebase():
            logger.error("Firebase not initialized")
            return None
            
        try:
            from firebase_admin import auth
            
            # Verify the token
            decoded = auth.verify_id_token(id_token, clock_skew_seconds=60)
            
            return {
                'uid': decoded.get('uid'),
                'phone_number': decoded.get('phone_number'),
                'email': decoded.get('email'),
                'email_verified': decoded.get('email_verified', False),
                'name': decoded.get('name', ''),  # For Google Sign-In display name
            }
            
        except Exception as e:
            logger.error(f"Token verification failed: {e}")
            return None
    
    @staticmethod
    def get_user_by_phone(phone: str) -> Optional[Dict]:
        """Get Firebase user by phone number"""
        if not _init_firebase():
            return None
            
        try:
            from firebase_admin import auth
            
            user = auth.get_user_by_phone_number(phone)
            return {
                'uid': user.uid,
                'phone_number': user.phone_number,
                'email': user.email,
            }
        except Exception:
            return None
