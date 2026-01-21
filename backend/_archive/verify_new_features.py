
import json
import time
import random
import urllib.request
import urllib.error
import urllib.parse

BASE_URL = "http://127.0.0.1:8000"
RUN_ID = str(random.randint(1000, 9999))
TEST_USER_EMAIL = f"privacy_urllib_{RUN_ID}@example.com"
TEST_PASSWORD = "password123"

def make_request(method, url, data=None, headers=None):
    if headers is None:
        headers = {}
    
    encoded_data = None
    if data:
        encoded_data = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
        
    req = urllib.request.Request(url, data=encoded_data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            return e.code, json.loads(body)
        except:
            return e.code, body
    except Exception as e:
        print(f"Request failed: {e}")
        return None, str(e)

def login_web_form(username, password):
    # Auth endpoint expects form data, not JSON usually! 
    # Wait, my app's /token endpoint is OAuth2PasswordRequestForm
    # So it needs form-data/x-www-form-urlencoded
    url = f"{BASE_URL}/api/auth/token"
    data = urllib.parse.urlencode({
        "username": username,
        "password": password
    }).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

def run_tests():
    print(f"🚀 Starting Verification Tests (Run ID: {RUN_ID})...")
    
    # 1. Register
    print("Registering...")
    status, res = make_request("POST", f"{BASE_URL}/api/auth/register", {
        "email": TEST_USER_EMAIL,
        "password": TEST_PASSWORD,
        "first_name": "Lib",
        "last_name": "Tester",
        "phone": "+919999999999"
    })
    
    if status != 200:
        print(f"Registration status: {status}, {res}")
        # Proceed if user already exists (400)
    
    # 2. Login
    print("Logging in...")
    status, res = login_web_form(TEST_USER_EMAIL, TEST_PASSWORD)
    
    if status != 200:
        print(f"❌ Login failed: {status} {res}")
        return

    token = res.get("access_token")
    if not token:
        print("❌ No token in response")
        return
        
    headers = {"Authorization": f"Bearer {token}"}
    print("✅ Logged in")

    # 1. Test Consent: WITHDRAW
    print("\n1️⃣  Testing Privacy Redaction (No Consent)...")
    status, _ = make_request("POST", f"{BASE_URL}/api/privacy/consent/training-data", 
                           {"consent": False, "version": "1.0"}, headers)
    
    scam_url_no_consent = f"http://scam-no-consent-{RUN_ID}.com"
    status, res = make_request("POST", f"{BASE_URL}/api/manual/analyze", {
        "content": f"URGENT! Click {scam_url_no_consent} to win",
        "content_type": "text"
    }, headers)
    
    print(f"   Scan Risk: {res.get('risk_level')}")
    
    # Verify Redaction
    time.sleep(1)
    status, data = make_request("GET", f"{BASE_URL}/api/reputation/export/training-data?format=jsonl", headers=headers)
    
    found_redacted = False
    if data and "data" in data:
        for item in data["data"]:
            messages = item.get("messages", [])
            for msg in messages:
                if "REDACTED" in msg.get("content", ""):
                    found_redacted = True
                    break
    
    if found_redacted:
        print("✅ Success: Found REDACTED data")
    else:
        print("⚠️ Warning: Redacted data not found")

    # 2. Test Consent: GIVE
    print("\n2️⃣  Testing Data Collection (With Consent)...")
    make_request("POST", f"{BASE_URL}/api/privacy/consent/training-data", 
                {"consent": True, "version": "1.0"}, headers)
    
    scam_url_consent = f"http://scam-with-consent-{RUN_ID}.com"
    unique_msg = f"URGENT! Click {scam_url_consent} to win PRIZE {RUN_ID}"
    
    make_request("POST", f"{BASE_URL}/api/manual/analyze", {
        "content": unique_msg,
        "content_type": "text"
    }, headers)
    
    time.sleep(1)
    status, data = make_request("GET", f"{BASE_URL}/api/reputation/export/training-data?format=jsonl", headers=headers)
    
    found_full = False
    if data and "data" in data:
        for item in data["data"]:
             for msg in item.get("messages", []):
                if unique_msg in msg.get("content", ""):
                    found_full = True
                    break
    
    if found_full:
        print("✅ Success: Found FULL data")
    else:
        print("❌ Failure: Full data not found")

    # 3. Test Auto-Blacklist
    print("\n3️⃣  Testing Auto-Blacklist Speed...")
    start = time.time()
    status, res = make_request("POST", f"{BASE_URL}/api/manual/analyze", {
        "content": scam_url_consent,
        "content_type": "url"
    }, headers)
    duration = time.time() - start
    
    print(f"   Response Time: {duration:.3f}s")
    if duration < 1.0:
        print("✅ Success: Fast response")
    else:
        print("⚠️ Warning: Slow response")

if __name__ == "__main__":
    run_tests()
