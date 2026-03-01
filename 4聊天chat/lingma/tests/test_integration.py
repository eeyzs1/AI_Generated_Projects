import pytest
import asyncio
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, Mock
import json

class TestUserJourney:
    """Test complete user journey from registration to messaging"""
    
    def test_complete_user_workflow(self, client):
        """Test complete workflow: register -> login -> create room -> send message"""
        # Step 1: Register new user
        register_response = client.post("/register", json={
            "username": "journeyuser",
            "email": "journey@example.com",
            "password": "journeypassword"
        })
        assert register_response.status_code == 200
        
        # Step 2: Login
        login_response = client.post("/login", json={
            "username": "journeyuser",
            "password": "journeypassword"
        })
        assert login_response.status_code == 200
        token = login_response.json()["access_token"]
        
        # Step 3: Create authenticated client
        auth_client = TestClient(client.app)
        auth_client.headers = {"Authorization": f"Bearer {token}"}
        
        # Step 4: Create room
        room_response = auth_client.post("/rooms", json={"name": "Journey Test Room"})
        assert room_response.status_code == 200
        room_id = room_response.json()["id"]
        
        # Step 5: Send message
        message_response = auth_client.post("/messages", json={
            "content": "Hello from journey test!",
            "room_id": room_id
        })
        assert message_response.status_code == 200
        
        # Step 6: Verify message was saved
        messages_response = auth_client.get(f"/messages/room/{room_id}")
        assert messages_response.status_code == 200
        messages = messages_response.json()
        assert len(messages) == 1
        assert messages[0]["content"] == "Hello from journey test!"

class TestMultiUserScenario:
    """Test scenarios involving multiple users"""
    
    def test_user_invitation_workflow(self, client, test_user, test_user2):
        """Test user invitation and messaging between invited users"""
        # Login as first user
        login_response = client.post("/login", json={
            "username": "testuser",
            "password": "testpassword"
        })
        token1 = login_response.json()["access_token"]
        client1 = TestClient(client.app)
        client1.headers = {"Authorization": f"Bearer {token1}"}
        
        # Create room
        room_response = client1.post("/rooms", json={"name": "Invitation Test Room"})
        room_id = room_response.json()["id"]
        
        # Invite second user
        invite_response = client1.post(f"/rooms/{room_id}/invite", json={
            "user_id": test_user2.id
        })
        assert invite_response.status_code == 200
        
        # Login as second user
        login_response2 = client.post("/login", json={
            "username": "testuser2",
            "password": "testpassword2"
        })
        token2 = login_response2.json()["access_token"]
        client2 = TestClient(client.app)
        client2.headers = {"Authorization": f"Bearer {token2}"}
        
        # Second user sends message to room
        message_response = client2.post("/messages", json={
            "content": "Hello from invited user!",
            "room_id": room_id
        })
        assert message_response.status_code == 200
        
        # First user should be able to see the message
        messages_response = client1.get(f"/messages/room/{room_id}")
        messages = messages_response.json()
        assert len(messages) == 1
        assert messages[0]["content"] == "Hello from invited user!"

class TestWebSocketIntegration:
    """Test WebSocket integration with REST API"""
    
    @pytest.mark.asyncio
    async def test_websocket_message_broadcast(self, db_session, test_user, test_room):
        """Test that WebSocket messages are properly broadcast"""
        from services.ws_service import manager
        
        # Mock WebSocket connections
        ws1 = MockWebSocket()
        ws2 = MockWebSocket()
        
        # Connect two users to the same room
        await manager.connect(ws1, user_id=1, room_id=test_room.id)
        await manager.connect(ws2, user_id=2, room_id=test_room.id)
        
        # Simulate message sending through WebSocket
        message_data = {
            "type": "message",
            "room_id": test_room.id,
            "content": "WebSocket test message"
        }
        
        # This would normally come from the WebSocket endpoint
        # For testing, we'll simulate the broadcast directly
        await manager.broadcast_to_room(
            json.dumps(message_data),
            test_room.id,
            exclude_user=1
        )
        
        # Verify ws2 received the message (ws1 excluded)
        assert len(ws2.sent_messages) == 1
        received_message = json.loads(ws2.sent_messages[0])
        assert received_message["type"] == "message"
        assert received_message["content"] == "WebSocket test message"

class TestErrorHandling:
    """Test error handling scenarios"""
    
    def test_database_error_handling(self, client, monkeypatch):
        """Test graceful error handling for database issues"""
        # Mock database error
        def mock_db_error(*args, **kwargs):
            raise Exception("Database connection failed")
        
        # Apply mock to a service function
        monkeypatch.setattr("services.chat_service.create_room", mock_db_error)
        
        # Try to create room - should handle error gracefully
        login_response = client.post("/login", json={
            "username": "testuser",
            "password": "testpassword"
        })
        token = login_response.json()["access_token"]
        auth_client = TestClient(client.app)
        auth_client.headers = {"Authorization": f"Bearer {token}"}
        
        response = auth_client.post("/rooms", json={"name": "Error Test Room"})
        # Should return appropriate error status
        assert response.status_code in [500, 422]  # Internal server error or validation error
    
    def test_invalid_token_handling(self, client):
        """Test handling of invalid authentication tokens"""
        # Try to access protected endpoint with invalid token
        bad_client = TestClient(client.app)
        bad_client.headers = {"Authorization": "Bearer invalid-token"}
        
        response = bad_client.get("/users/me")
        assert response.status_code == 401

class TestPerformanceScenarios:
    """Test performance and scalability scenarios"""
    
    def test_multiple_concurrent_requests(self, client, test_user):
        """Test handling of concurrent requests"""
        import threading
        import time
        
        def make_request(client_instance, results, index):
            response = client_instance.get("/users/me")
            results[index] = response.status_code
        
        # Login first
        login_response = client.post("/login", json={
            "username": "testuser",
            "password": "testpassword"
        })
        token = login_response.json()["access_token"]
        
        # Create multiple authenticated clients
        clients = []
        for i in range(5):
            auth_client = TestClient(client.app)
            auth_client.headers = {"Authorization": f"Bearer {token}"}
            clients.append(auth_client)
        
        # Make concurrent requests
        results = [None] * 5
        threads = []
        
        for i, client_instance in enumerate(clients):
            thread = threading.Thread(target=make_request, args=(client_instance, results, i))
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # All requests should succeed
        assert all(status == 200 for status in results if status is not None)

class MockWebSocket:
    """Enhanced mock WebSocket for integration testing"""
    def __init__(self):
        self.sent_messages = []
        self.received_messages = []
        self.accepted = False
        self.closed = False
    
    async def accept(self):
        self.accepted = True
    
    async def send_text(self, message):
        self.sent_messages.append(message)
    
    async def receive_text(self):
        if self.received_messages:
            return self.received_messages.pop(0)
        return ""
    
    async def close(self):
        self.closed = True
    
    def queue_message(self, message):
        """Queue a message to be received"""
        self.received_messages.append(message)