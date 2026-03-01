"""Test utilities and helper functions"""

import random
import string
from datetime import datetime, timedelta
from typing import Dict, Any, List
import json

class TestDataGenerator:
    """Utility class for generating test data"""
    
    @staticmethod
    def random_string(length: int = 10) -> str:
        """Generate random string"""
        return ''.join(random.choices(string.ascii_letters + string.digits, k=length))
    
    @staticmethod
    def random_email() -> str:
        """Generate random email address"""
        return f"{TestDataGenerator.random_string(8)}@{TestDataGenerator.random_string(5)}.com"
    
    @staticmethod
    def random_username() -> str:
        """Generate random username"""
        return TestDataGenerator.random_string(12)
    
    @staticmethod
    def random_password() -> str:
        """Generate random password"""
        return TestDataGenerator.random_string(15)
    
    @staticmethod
    def random_room_name() -> str:
        """Generate random room name"""
        adjectives = ['Awesome', 'Cool', 'Fun', 'Exciting', 'Amazing', 'Great']
        nouns = ['Chat', 'Room', 'Group', 'Team', 'Club', 'Community']
        return f"{random.choice(adjectives)} {random.choice(nouns)} {random.randint(1, 1000)}"
    
    @staticmethod
    def random_message_content() -> str:
        """Generate random message content"""
        messages = [
            "Hello everyone!",
            "How are you doing?",
            "This is a test message",
            "Great to be here!",
            "Looking forward to chatting",
            "Thanks for the invitation",
            "See you later!",
            "Have a great day!"
        ]
        return random.choice(messages)

class TestAssertions:
    """Custom assertion methods for tests"""
    
    @staticmethod
    def assert_user_data_valid(user_data: Dict[str, Any], expected_username: str = None):
        """Assert user data has required fields and valid structure"""
        required_fields = ['id', 'username', 'email', 'is_active', 'is_online', 'created_at']
        for field in required_fields:
            assert field in user_data, f"Missing required field: {field}"
        
        # Validate data types
        assert isinstance(user_data['id'], int)
        assert isinstance(user_data['username'], str)
        assert isinstance(user_data['email'], str)
        assert isinstance(user_data['is_active'], bool)
        assert isinstance(user_data['is_online'], bool)
        
        # Validate username if provided
        if expected_username:
            assert user_data['username'] == expected_username
    
    @staticmethod
    def assert_room_data_valid(room_data: Dict[str, Any], expected_name: str = None):
        """Assert room data has required fields and valid structure"""
        required_fields = ['id', 'name', 'creator_id', 'created_at', 'members']
        for field in required_fields:
            assert field in room_data, f"Missing required field: {field}"
        
        # Validate data types
        assert isinstance(room_data['id'], int)
        assert isinstance(room_data['name'], str)
        assert isinstance(room_data['creator_id'], int)
        assert isinstance(room_data['members'], list)
        
        # Validate room name if provided
        if expected_name:
            assert room_data['name'] == expected_name
    
    @staticmethod
    def assert_message_data_valid(message_data: Dict[str, Any]):
        """Assert message data has required fields and valid structure"""
        required_fields = ['id', 'content', 'sender_id', 'room_id', 'created_at']
        for field in required_fields:
            assert field in message_data, f"Missing required field: {field}"
        
        # Validate data types
        assert isinstance(message_data['id'], int)
        assert isinstance(message_data['content'], str)
        assert isinstance(message_data['sender_id'], int)
        assert isinstance(message_data['room_id'], int)
        
        # Validate content length
        assert 1 <= len(message_data['content']) <= 1000

class TestHelpers:
    """Helper methods for common test operations"""
    
    @staticmethod
    def create_test_user(client, username=None, email=None, password=None):
        """Create a test user via API"""
        if username is None:
            username = TestDataGenerator.random_username()
        if email is None:
            email = TestDataGenerator.random_email()
        if password is None:
            password = TestDataGenerator.random_password()
        
        response = client.post("/register", json={
            "username": username,
            "email": email,
            "password": password
        })
        
        assert response.status_code == 200
        return response.json(), username, email, password
    
    @staticmethod
    def login_test_user(client, username, password):
        """Login test user and return authenticated client"""
        response = client.post("/login", json={
            "username": username,
            "password": password
        })
        
        assert response.status_code == 200
        token = response.json()["access_token"]
        
        auth_client = client.__class__(client.app)
        auth_client.headers = {"Authorization": f"Bearer {token}"}
        return auth_client, token
    
    @staticmethod
    def create_test_room(authenticated_client, room_name=None):
        """Create a test room via API"""
        if room_name is None:
            room_name = TestDataGenerator.random_room_name()
        
        response = authenticated_client.post("/rooms", json={"name": room_name})
        assert response.status_code == 200
        return response.json()
    
    @staticmethod
    def send_test_message(authenticated_client, room_id, content=None):
        """Send a test message via API"""
        if content is None:
            content = TestDataGenerator.random_message_content()
        
        response = authenticated_client.post("/messages", json={
            "content": content,
            "room_id": room_id
        })
        assert response.status_code == 200
        return response.json()

class MockWebSocketTester:
    """Helper for testing WebSocket functionality"""
    
    def __init__(self):
        self.connections = {}
        self.messages_sent = []
        self.messages_received = []
    
    def connect_user(self, user_id: int, room_id: int = None):
        """Simulate user WebSocket connection"""
        from services.ws_service import manager
        import asyncio
        
        mock_ws = MockWebSocket()
        asyncio.run(manager.connect(mock_ws, user_id, room_id))
        self.connections[user_id] = mock_ws
        return mock_ws
    
    def disconnect_user(self, user_id: int):
        """Simulate user WebSocket disconnection"""
        from services.ws_service import manager
        import asyncio
        
        if user_id in self.connections:
            mock_ws = self.connections[user_id]
            asyncio.run(manager.disconnect(mock_ws, user_id))
            del self.connections[user_id]
    
    def get_user_connection(self, user_id: int):
        """Get user's WebSocket connection"""
        return self.connections.get(user_id)
    
    def assert_message_sent(self, user_id: int, expected_content: str = None):
        """Assert that a message was sent to user"""
        connection = self.get_user_connection(user_id)
        assert connection is not None
        assert len(connection.sent_messages) > 0
        
        if expected_content:
            last_message = connection.sent_messages[-1]
            if isinstance(last_message, str):
                assert expected_content in last_message
            else:
                assert expected_content in str(last_message)

class MockWebSocket:
    """Enhanced mock WebSocket for testing"""
    def __init__(self):
        self.sent_messages: List[str] = []
        self.received_messages: List[str] = []
        self.accepted = False
        self.closed = False
    
    async def accept(self):
        self.accepted = True
    
    async def send_text(self, message: str):
        self.sent_messages.append(message)
    
    async def receive_text(self) -> str:
        if self.received_messages:
            return self.received_messages.pop(0)
        return ""
    
    async def close(self):
        self.closed = True
    
    def queue_message(self, message: str):
        """Queue a message to be received"""
        self.received_messages.append(message)

# Test data constants
TEST_CONSTANTS = {
    'MAX_MESSAGE_LENGTH': 1000,
    'MIN_PASSWORD_LENGTH': 6,
    'DEFAULT_ROOM_NAME': 'Test Room',
    'DEFAULT_MESSAGE_CONTENT': 'Hello World!',
    'TEST_TIMEOUT': 30  # seconds
}

def load_test_config():
    """Load test configuration from file or return defaults"""
    try:
        with open('tests/test_config.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        return {
            'database_url': 'sqlite:///./test.db',
            'test_timeout': 30,
            'max_concurrent_tests': 10
        }