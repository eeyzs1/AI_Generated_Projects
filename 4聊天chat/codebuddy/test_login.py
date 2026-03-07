import requests
import json

# Test login
url = "http://localhost:8001/api/auth/login"
data = {
    "username": "testuser",
    "password": "password123"
}

print("Testing login API...")
print(f"URL: {url}")
print(f"Data: {json.dumps(data, indent=2)}")

try:
    response = requests.post(url, json=data)
    print(f"\nStatus Code: {response.status_code}")
    print(f"Response: {response.text}")

    if response.status_code == 200:
        token_data = response.json()
        token = token_data.get("access_token")
        print(f"\nToken received (first 50 chars): {token[:50]}...")

        # Test protected endpoint
        me_url = "http://localhost:8001/api/auth/me"
        headers = {"Authorization": f"Bearer {token}"}

        print(f"\nTesting protected endpoint: {me_url}")
        me_response = requests.get(me_url, headers=headers)
        print(f"Status Code: {me_response.status_code}")
        print(f"Response: {me_response.text}")

except Exception as e:
    print(f"Error: {e}")
