"""Quick test to verify Firebase Admin SDK initialization works."""
import os, base64, json, sys

print("=== Firebase Init Test ===")

b64 = os.getenv("FIREBASE_CREDENTIALS_BASE64")
if not b64:
    print("ERROR: FIREBASE_CREDENTIALS_BASE64 not set")
    sys.exit(1)

print("Base64 env var length: " + str(len(b64)))

try:
    decoded = base64.b64decode(b64).decode("utf-8")
    info = json.loads(decoded)
    print("project_id: " + str(info.get("project_id")))
    print("client_email: " + str(info.get("client_email")))
except Exception as e:
    print("ERROR decoding base64: " + str(e))
    sys.exit(1)

try:
    import firebase_admin
    from firebase_admin import credentials, auth
    cred = credentials.Certificate(info)
    app = firebase_admin.initialize_app(cred)
    print("Firebase app initialized: " + app.name)
    print("SUCCESS: Firebase Admin SDK is working")
except Exception as e:
    print("ERROR initializing Firebase: " + str(e))
    sys.exit(1)
