import pytest
import asyncio
import json
from services.ws_service import ConnectionManager

class TestWebSocketService:
    
    @pytest.fixture
    def connection_manager(self):
        """Create a fresh connection manager for each test"""
        return ConnectionManager()
    
    @pytest.mark.asyncio
    async def test_connect_single_user(self, connection_manager, mock_websocket):
        """Test connecting a single user"""
        await connection_manager.connect(mock_websocket, user_id=1, room_id=1)
        
        assert 1 in connection_manager.active_connections
        assert mock_websocket in connection_manager.active_connections[1]
        assert connection_manager.user_rooms[1] == 1
        mock_websocket.accept.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_connect_multiple_connections_same_user(self, connection_manager):
        """Test multiple connections for the same user"""
        ws1 = MockWebSocket()
        ws2 = MockWebSocket()
        
        await connection_manager.connect(ws1, user_id=1)
        await connection_manager.connect(ws2, user_id=1)
        
        assert len(connection_manager.active_connections[1]) == 2
        assert ws1 in connection_manager.active_connections[1]
        assert ws2 in connection_manager.active_connections[1]
    
    def test_disconnect_last_connection(self, connection_manager, mock_websocket):
        """Test disconnecting the last connection for a user"""
        # First connect
        connection_manager.active_connections[1] = [mock_websocket]
        connection_manager.user_rooms[1] = 1
        
        # Then disconnect
        result = connection_manager.disconnect(mock_websocket, user_id=1)
        
        assert result is True
        assert 1 not in connection_manager.active_connections
        assert 1 not in connection_manager.user_rooms
    
    def test_disconnect_not_last_connection(self, connection_manager):
        """Test disconnecting when user has multiple connections"""
        ws1 = MockWebSocket()
        ws2 = MockWebSocket()
        
        connection_manager.active_connections[1] = [ws1, ws2]
        
        result = connection_manager.disconnect(ws1, user_id=1)
        
        assert result is False
        assert len(connection_manager.active_connections[1]) == 1
        assert ws1 not in connection_manager.active_connections[1]
        assert ws2 in connection_manager.active_connections[1]
    
    @pytest.mark.asyncio
    async def test_send_personal_message(self, connection_manager, mock_websocket):
        """Test sending personal message to user"""
        connection_manager.active_connections[1] = [mock_websocket]
        message = "Hello User 1"
        
        await connection_manager.send_personal_message(message, user_id=1)
        
        mock_websocket.send_text.assert_called_once_with(message)
    
    @pytest.mark.asyncio
    async def test_send_personal_message_no_connections(self, connection_manager):
        """Test sending message to user with no connections"""
        # Should not raise exception
        await connection_manager.send_personal_message("test", user_id=999)
    
    @pytest.mark.asyncio
    async def test_broadcast_to_room(self, connection_manager):
        """Test broadcasting message to room"""
        ws1 = MockWebSocket()
        ws2 = MockWebSocket()
        ws3 = MockWebSocket()  # Different room
        
        # User 1 and 2 in room 1, user 3 in room 2
        connection_manager.active_connections[1] = [ws1]
        connection_manager.active_connections[2] = [ws2]
        connection_manager.active_connections[3] = [ws3]
        connection_manager.user_rooms[1] = 1
        connection_manager.user_rooms[2] = 1
        connection_manager.user_rooms[3] = 2
        
        message = "Room message"
        await connection_manager.broadcast_to_room(message, room_id=1, exclude_user=1)
        
        # ws1 should not receive (excluded), ws2 should receive, ws3 should not (different room)
        ws1.send_text.assert_not_called()
        ws2.send_text.assert_called_once_with(message)
        ws3.send_text.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_broadcast_user_status(self, connection_manager):
        """Test broadcasting user status change"""
        ws1 = MockWebSocket()
        ws2 = MockWebSocket()
        
        connection_manager.active_connections[1] = [ws1]
        connection_manager.active_connections[2] = [ws2]
        
        await connection_manager.broadcast_user_status(user_id=1, is_online=True)
        
        # Both users should receive the status update
        ws1.send_text.assert_called_once()
        ws2.send_text.assert_called_once()
        
        # Check that the message contains expected data
        call1_args = ws1.send_text.call_args[0][0]
        call2_args = ws2.send_text.call_args[0][0]
        
        # Parse JSON to verify structure
        message1 = json.loads(call1_args)
        message2 = json.loads(call2_args)
        
        assert message1["type"] == "user_status"
        assert message1["user_id"] == 1
        assert message1["is_online"] is True
        assert "timestamp" in message1
    
    @pytest.mark.asyncio
    async def test_broadcast_message(self, connection_manager):
        """Test broadcasting message to all users"""
        ws1 = MockWebSocket()
        ws2 = MockWebSocket()
        
        connection_manager.active_connections[1] = [ws1]
        connection_manager.active_connections[2] = [ws2]
        
        message = "Broadcast message"
        await connection_manager.broadcast_message(message)
        
        ws1.send_text.assert_called_once_with(message)
        ws2.send_text.assert_called_once_with(message)
    
    def test_user_room_mapping(self, connection_manager, mock_websocket):
        """Test user to room mapping"""
        # Connect user to room
        connection_manager.connect(mock_websocket, user_id=1, room_id=5)
        
        assert connection_manager.user_rooms[1] == 5
        
        # Connect to different room
        connection_manager.connect(MockWebSocket(), user_id=1, room_id=10)
        assert connection_manager.user_rooms[1] == 10

class MockWebSocket:
    """Mock WebSocket class for testing"""
    def __init__(self):
        self.sent_messages = []
        self.accepted = False
    
    async def accept(self):
        self.accepted = True
    
    async def send_text(self, message):
        self.sent_messages.append(message)
    
    async def receive_text(self):
        return ""
    
    async def close(self):
        pass