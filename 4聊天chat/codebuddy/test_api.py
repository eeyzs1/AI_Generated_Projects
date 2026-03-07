import requests
import json

url = "http://localhost:8001/api/auth/register"
data = {
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
}

print("Testing registration API...")
print(f"URL: {url}")
print(f"Data: {json.dumps(data, indent=2)}")

try:
    response = requests.post(url, json=data)
    print(f"\nStatus Code: {response.status_code}")
    print(f"Response: {response.text}")
    print(f"Headers: {dict(response.headers)}")
except Exception as e:
    print(f"Error: {e}")
