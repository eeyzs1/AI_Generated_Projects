import pytest
from fastapi.testclient import TestClient
import json

class TestAuthEndpoints:
    
    def test_register_user_success(self, client):
        """Test successful user registration"""
        response = client.post("/register", json={
            "username": "newuser",
            "email": "newuser@example.com",
            "password": "password123"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "newuser"
        assert data["email"] == "newuser@example.com"
        assert "id" in data
        assert data["is_active"] is True
    
    def test_register_duplicate_username(self, client, test_user):
        """Test registration with duplicate username"""
        response = client.post("/register", json={
            "username": "testuser",  # Same as existing user
            "email": "different@example.com",
            "password": "password123"
        })
        
        assert response.status_code == 400
        assert "Username already registered" in response.json()["detail"]
    
    def test_register_duplicate_email(self, client, test_user):
        """Test registration with duplicate email"""
        response = client.post("/register", json={
            "username": "differentuser",
            "email": "test@example.com",  # Same as existing user
            "password": "password123"
        })
        
        assert response.status_code == 400
        assert "Email already registered" in response.json()["detail"]
    
    def test_login_success(self, client, test_user):
        """Test successful login"""
        response = client.post("/login", json={
            "username": "testuser",
            "password": "testpassword"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    def test_login_wrong_credentials(self, client):
        """Test login with wrong credentials"""
        response = client.post("/login", json={
            "username": "testuser",
            "password": "wrongpassword"
        })
        
        assert response.status_code == 401
        assert "Incorrect username or password" in response.json()["detail"]
    
    def test_get_current_user_authenticated(self, authenticated_client):
        """Test getting current user info when authenticated"""
        response = authenticated_client.get("/users/me")
        
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"
    
    def test_get_current_user_unauthenticated(self, client):
        """Test getting current user without authentication"""
        response = client.get("/users/me")
        
        assert response.status_code == 401

class TestRoomEndpoints:
    
    def test_create_room_success(self, authenticated_client):
        """Test successful room creation"""
        response = authenticated_client.post("/rooms", json={
            "name": "My New Room"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "My New Room"
        assert "id" in data
        assert data["creator_id"] is not None
    
    def test_create_room_unauthenticated(self, client):
        """Test room creation without authentication"""
        response = client.post("/rooms", json={"name": "Test Room"})
        
        assert response.status_code == 401
    
    def test_get_user_rooms(self, authenticated_client, test_room):
        """Test getting user's rooms"""
        response = authenticated_client.get("/rooms")
        
        assert response.status_code == 200
        rooms = response.json()
        assert len(rooms) >= 1
        # Check that our test room is in the list
        room_names = [room["name"] for room in rooms]
        assert "Test Room" in room_names
    
    def test_invite_user_to_room_success(self, authenticated_client, test_room, test_user2):
        """Test successful user invitation"""
        response = authenticated_client.post(f"/rooms/{test_room.id}/invite", json={
            "user_id": test_user2.id
        })
        
        assert response.status_code == 200
        data = response.json()
        invited_user_ids = [member["id"] for member in data["members"]]
        assert test_user2.id in invited_user_ids
    
    def test_invite_to_nonexistent_room(self, authenticated_client, test_user2):
        """Test inviting to non-existent room"""
        response = authenticated_client.post("/rooms/99999/invite", json={
            "user_id": test_user2.id
        })
        
        assert response.status_code == 404

class TestMessageEndpoints:
    
    def test_send_message_success(self, authenticated_client, test_room):
        """Test successful message sending"""
        response = authenticated_client.post("/messages", json={
            "content": "Hello everyone!",
            "room_id": test_room.id
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["content"] == "Hello everyone!"
        assert data["room_id"] == test_room.id
        assert data["sender_id"] is not None
    
    def test_send_message_to_nonexistent_room(self, authenticated_client):
        """Test sending message to non-existent room"""
        response = authenticated_client.post("/messages", json={
            "content": "Test message",
            "room_id": 99999
        })
        
        assert response.status_code == 404
    
    def test_get_room_messages_success(self, authenticated_client, test_room):
        """Test getting room messages"""
        # First send a message
        authenticated_client.post("/messages", json={
            "content": "Test message for retrieval",
            "room_id": test_room.id
        })
        
        response = authenticated_client.get(f"/messages/room/{test_room.id}")
        
        assert response.status_code == 200
        messages = response.json()
        assert len(messages) >= 1
        assert messages[0]["content"] == "Test message for retrieval"
    
    def test_get_messages_from_unauthorized_room(self, authenticated_client, test_user2):
        """Test getting messages from room user is not member of"""
        # Create room with different user
        client2 = TestClient(app)  # Need to create new client for different user
        # Login as second user
        login_resp = client2.post("/login", json={
            "username": "testuser2",
            "password": "testpassword2"
        })
        token = login_resp.json()["access_token"]
        client2.headers = {"Authorization": f"Bearer {token}"}
        
        # Create room with second user
        room_resp = client2.post("/rooms", json={"name": "Private Room"})
        room_id = room_resp.json()["id"]
        
        # Try to get messages with first user
        response = authenticated_client.get(f"/messages/room/{room_id}")
        
        assert response.status_code == 403

# Import app for TestMessageEndpoints.test_get_messages_from_unauthorized_room
from main import app