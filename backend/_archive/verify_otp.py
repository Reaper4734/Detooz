
import asyncio
import urllib.request
import urllib.error
import urllib.parse
import json
import time

BASE_URL = "http://127.0.0.1:8000"

def make_request(method, url, data=None, headers=None):
    if headers is None: headers = {}
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

def login(email, password="password123"):
    # Login via form endpoint
    url = f"{BASE_URL}/api/auth/token"
    data = urllib.parse.urlencode({
        "username": email,
        "password": password
    }).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read().decode())
            return res.get("access_token")
    except Exception as e:
        print(f"Login failed for {email}: {e}")
        return None

def register(email, first_name, last_name):
    status, res = make_request("POST", f"{BASE_URL}/api/auth/register", {
        "email": email,
        "password": "password123",
        "first_name": first_name,
        "last_name": last_name,
        "phone": "+919999999999"
    })
    if status != 200 and status != 400: # 400 means already exists, which is fine
        print(f"Registration warning: {status} {res}")

def run_tests():
    print("🚀 Verifying In-Memory OTP Logic...")
    
    import random
    run_id = random.randint(1000, 9999)
    
    # 1. Setup Users
    email_protected = f"protected_otp_{run_id}@test.com"
    email_guardian = f"guardian_otp_{run_id}@test.com"
    
    register(email_protected, "Protected", "User")
    register(email_guardian, "Guardian", "User")
    
    token_p = login(email_protected)
    token_g = login(email_guardian)
    
    if not token_p or not token_g:
        print("❌ Auth failed")
        return

    headers_p = {"Authorization": f"Bearer {token_p}"}
    headers_g = {"Authorization": f"Bearer {token_g}"}

    # 2. Generate OTP (User A)
    print("\n1️⃣  Generating OTP (Protected User)...")
    status, res = make_request("POST", f"{BASE_URL}/api/guardian-link/generate-otp", headers=headers_p)
    
    if status != 200:
        print(f"❌ Generation failed: {res}")
        return

    otp = res["otp_code"]
    print(f"✅ OTP Generated: {otp} (Stored in Memory)")
    
    # 3. Verify OTP (User B)
    print("\n2️⃣  Verifying OTP (Guardian User)...")
    status, res = make_request("POST", f"{BASE_URL}/api/guardian-link/verify-otp", {
        "user_email": email_protected,
        "otp_code": otp
    }, headers=headers_g)
    
    if status == 200:
         print(f"✅ Verification Successful: {res['message']}")
    else:
         print(f"❌ Verification failed: {res}")
         return

    # 4. Challenge: Re-use OTP (Should fail as it's deleted)
    print("\n3️⃣  Testing Re-use (Should Fail)...")
    status, res = make_request("POST", f"{BASE_URL}/api/guardian-link/verify-otp", {
        "user_email": email_protected,
        "otp_code": otp
    }, headers=headers_g)
    
    if status == 400:
        print("✅ Success: OTP cannot be reused (Deleted from memory)")
    else:
        print(f"❌ Failure: OTP reused? Status: {status}")

if __name__ == "__main__":
    run_tests()
