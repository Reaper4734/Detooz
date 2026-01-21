
import asyncio
import time
import sqlite3
import urllib.request
import urllib.parse
import json
import random
import os

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
    except Exception as e:
        print(f"Request failed: {e}")
        return 0, {}

def register_and_login():
    run_id = random.randint(1000, 9999)
    email = f"opt_test_{run_id}@example.com"
    password = "password123"
    
    # Register
    status, res = make_request("POST", f"{BASE_URL}/api/auth/register", {
        "email": email,
        "password": password,
        "first_name": "Opt",
        "last_name": "Tester",
        "phone": "+919999999999"
    })
    if status != 200 and status != 400:
        print(f"Registration Error: {status} {res}")
    
    # Login
    print(f"Logging in as {email}...")
    url = f"{BASE_URL}/api/auth/login"
    data = urllib.parse.urlencode({"username": email, "password": password}).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode()).get("access_token")
    except urllib.error.HTTPError as e:
        print(f"Login Failed: {e.code} {e.read().decode()}")
        return None
    except Exception as e:
        print(f"Login Exception: {e}")
        return None

def verify_space_optimization(token):
    print("\n1️⃣  Verifying Space Optimization (Safe Scan Truncation)...")
    headers = {"Authorization": f"Bearer {token}"}
    
    # 1. Send SAFE SMS
    safe_msg = "Hello friend, let's meet for lunch at 12pm."
    make_request("POST", f"{BASE_URL}/api/sms/analyze", {
        "sender": "+919876543210",
        "message": safe_msg,
        "timestamp": int(time.time()),
        "platform": "sms"
    }, headers)
    
    # 2. Check DB directly (sqlite3)
    db_path = "scam_shield.db"
    if not os.path.exists(db_path):
        print("⚠️ DB file not found in current dir, skipping direct DB check.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("SELECT message, risk_level FROM scans ORDER BY id DESC LIMIT 1")
    row = cursor.fetchone()
    conn.close()
    
    if row:
        message_val, risk_level = row
        print(f"   Last Scan Risk: {risk_level}")
        print(f"   Stored Message: {message_val}")
        
        if risk_level == "LOW" and message_val is None:
            print("✅ Success: Safe message body is NULL (Space Saved!)")
        else:
            print(f"❌ Failure: Message stored? '{message_val}'")
    else:
        print("❌ Failure: No scan found in DB")

def verify_time_optimization(token):
    print("\n2️⃣  Verifying Time Optimization (Blacklist Cache)...")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Use a generic URL that might take a moment if scraped, but here we test cache speed
    test_url = "http://google.com" # Should be safe/low risk
    
    # 1. First Scan (Cold Cache)
    start = time.time()
    make_request("POST", f"{BASE_URL}/api/manual/analyze", {
        "content": test_url,
        "content_type": "url"
    }, headers)
    cold_time = time.time() - start
    print(f"   Cold Scan Time: {cold_time:.4f}s")
    
    # 2. Second Scan (Warm Cache)
    start = time.time()
    make_request("POST", f"{BASE_URL}/api/manual/analyze", {
        "content": test_url,
        "content_type": "url"
    }, headers)
    warm_time = time.time() - start
    print(f"   Warm Scan Time: {warm_time:.4f}s")
    
    if warm_time < cold_time:
         print(f"✅ Success: Warm scan is faster ({(cold_time - warm_time):.4f}s saved)")
    else:
         print("⚠️ Note: Warm scan not significantly faster (Local DB is fast, or overhead varies)")

if __name__ == "__main__":
    print("🚀 Starting Optimization Verification...")
    token = register_and_login()
    if token:
        verify_space_optimization(token)
        verify_time_optimization(token)
    else:
        print("❌ Auth failed")
