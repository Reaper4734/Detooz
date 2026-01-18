import requests

BASE_URL = "http://localhost:8000/api/auth/register"

user1 = {
    "email": "test_unique_1@example.com",
    "password": "password123",
    "name": "Test User 1",
    "phone": "9998887777"
}

user2 = {
    "email": "test_unique_2@example.com",
    "password": "password123",
    "name": "Test User 2",
    "phone": "9998887777"  # Same phone!
}

def run_test():
    print("Registering User 1...")
    res1 = requests.post(BASE_URL, json=user1)
    print(f"User 1: {res1.status_code}")
    if res1.status_code != 200:
        print(res1.text)

    print("\nRegistering User 2 (Duplicate Phone)...")
    res2 = requests.post(BASE_URL, json=user2)
    print(f"User 2: {res2.status_code}")
    print(res2.text)
    
    if res2.status_code == 400 and "Phone number already registered" in res2.text:
        print("\nSUCCESS: Duplicate phone blocked!")
    else:
        print("\nFAILURE: Duplicate phone allowed!")

if __name__ == "__main__":
    run_test()
