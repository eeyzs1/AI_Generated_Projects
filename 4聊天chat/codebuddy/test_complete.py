import requests
import json
import time

BASE_URL = "http://localhost:8001"

def test_registration():
    """Test user registration"""
    print("1. Testing User Registration...")
    url = f"{BASE_URL}/api/auth/register"
    data = {
        "username": "user1",
        "email": "user1@example.com",
        "password": "password123"
    }

    response = requests.post(url, json=data)
    print(f"   Status: {response.status_code}")
    if response.status_code == 201:
        print(f"   Response: {response.json()}")
        return True
    else:
        print(f"   Error: {response.text}")
        return False

def test_login():
    """Test user login"""
    print("\n2. Testing User Login...")
    url = f"{BASE_URL}/api/auth/login"
    data = {
        "username": "testuser",
        "password": "password123"
    }

    response = requests.post(url, json=data)
    print(f"   Status: {response.status_code}")
    if response.status_code == 200:
        token_data = response.json()
        print(f"   Token received: {token_data['access_token'][:50]}...")
        return token_data['access_token']
    else:
        print(f"   Error: {response.text}")
        return None

def test_get_current_user(token):
    """Test getting current user info"""
    print("\n3. Testing Get Current User...")
    url = f"{BASE_URL}/api/auth/me"
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers)
    print(f"   Status: {response.status_code}")
    if response.status_code == 200:
        print(f"   User: {response.json()}")
        return True
    else:
        print(f"   Error: {response.text}")
        return False

def test_create_room(token):
    """Test creating a chat room"""
    print("\n4. Testing Create Chat Room...")
    url = f"{BASE_URL}/api/rooms"
    headers = {"Authorization": f"Bearer {token}"}
    data = {"name": "Test Room"}

    response = requests.post(url, json=data, headers=headers)
    print(f"   Status: {response.status_code}")
    if response.status_code == 201:
        room = response.json()
        print(f"   Room created: {room}")
        return room['id']
    else:
        print(f"   Error: {response.text}")
        return None

def test_get_rooms(token):
    """Test getting user's rooms"""
    print("\n5. Testing Get User Rooms...")
    url = f"{BASE_URL}/api/rooms"
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers)
    print(f"   Status: {response.status_code}")
    if response.status_code == 200:
        rooms = response.json()
        print(f"   Rooms: {json.dumps(rooms, indent=4)}")
        return True
    else:
        print(f"   Error: {response.text}")
        return False

def test_get_users(token):
    """Test getting all users"""
    print("\n6. Testing Get All Users...")
    url = f"{BASE_URL}/api/users"
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers)
    print(f"   Status: {response.status_code}")
    if response.status_code == 200:
        users = response.json()
        print(f"   Users: {json.dumps(users, indent=4)}")
        return True
    else:
        print(f"   Error: {response.text}")
        return False

def main():
    print("="*50)
    print("Chat App API Testing")
    print("="*50)

    # Test 1: Register another user
    test_registration()

    # Test 2: Login
    token = test_login()
    if not token:
        print("\nLogin failed, cannot continue with other tests")
        return

    # Test 3: Get current user
    test_get_current_user(token)

    # Test 4: Create room
    room_id = test_create_room(token)

    # Test 5: Get rooms
    test_get_rooms(token)

    # Test 6: Get users
    test_get_users(token)

    print("\n" + "="*50)
    print("API Testing Complete!")
    print("="*50)
    print("\nFrontend URL: http://localhost:3000")
    print("Backend API: http://localhost:8001")
    print("API Docs: http://localhost:8001/docs")

if __name__ == "__main__":
    main()
