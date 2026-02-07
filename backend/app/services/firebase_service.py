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
    """Initialize Firebase Admin SDK - supports both file and base64 env var"""
    global _firebase_app
    
    if _firebase_app is not None:
        return _firebase_app
    
    try:
        import firebase_admin
        from firebase_admin import credentials
        import base64
        import json
        
        # Method 1: Base64-encoded env var (for cloud deployment)
        cred_base64 = os.getenv('FIREBASE_CREDENTIALS_BASE64')
        if cred_base64:
            try:
                cred_json = base64.b64decode(cred_base64).decode('utf-8')
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                _firebase_app = firebase_admin.initialize_app(cred)
                logger.info("Firebase initialized from FIREBASE_CREDENTIALS_BASE64")
                return _firebase_app
            except Exception as e:
                logger.error(f"Failed to load base64 credentials: {e}")
        
        # Method 2: File path (for local development)
        cred_path = os.getenv('FIREBASE_SERVICE_ACCOUNT', 'firebase-service-account.json')
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info("Firebase initialized from file")
            return _firebase_app
        
        logger.warning(f"Firebase credentials not found (file: {cred_path})")
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
            logger.error("Firebase not initialized - check service account file")
            return None
        
        # Quick validation
        if not id_token or len(id_token) < 100:
            logger.error(f"Token too short or empty: len={len(id_token) if id_token else 0}")
            return None
            
        try:
            from firebase_admin import auth
            
            # Verify the token with max clock skew (60 seconds is max allowed)
            # This handles slight clock drift between client and server
            decoded = auth.verify_id_token(
                id_token, 
                check_revoked=False,  # Don't check revocation for faster verification
                clock_skew_seconds=60  # Max allowed by firebase-admin
            )
            
            logger.info(f"Token verified for UID: {decoded.get('uid', 'unknown')[:8]}...")
            
            return {
                'uid': decoded.get('uid'),
                'phone_number': decoded.get('phone_number'),
                'email': decoded.get('email'),
                'email_verified': decoded.get('email_verified', False),
                'name': decoded.get('name', ''),  # For Google Sign-In display name
            }
            
        except auth.ExpiredIdTokenError as e:
            logger.error(f"Token EXPIRED: {e}")
            return None
        except auth.RevokedIdTokenError as e:
            logger.error(f"Token REVOKED: {e}")
            return None
        except auth.InvalidIdTokenError as e:
            logger.error(f"Token INVALID: {e}")
            return None
        except auth.CertificateFetchError as e:
            logger.error(f"Certificate fetch error (network issue?): {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected token verification error: {type(e).__name__}: {e}")
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
