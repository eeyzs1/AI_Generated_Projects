import pytest
from fastapi import HTTPException
from services.chat_service import (
    create_room, get_rooms_by_user, get_room_by_id, invite_user_to_room,
    send_message, get_messages_by_room, get_online_users, set_user_online_status
)
from schemas.room import RoomCreate, RoomInvite
from schemas.message import MessageCreate

class TestChatService:
    
    def test_create_room(self, db_session, test_user):
        """Test creating a new room"""
        room_create = RoomCreate(name="New Test Room")
        room = create_room(db_session, room_create, test_user.id)
        
        assert room.name == "New Test Room"
        assert room.creator_id == test_user.id
        assert len(room.members) == 1
        assert test_user in room.members
    
    def test_get_rooms_by_user(self, db_session, test_user, test_room):
        """Test getting rooms for a user"""
        rooms = get_rooms_by_user(db_session, test_user.id)
        assert len(rooms) >= 1
        assert test_room in rooms
    
    def test_get_room_by_id(self, db_session, test_room):
        """Test getting room by ID"""
        room = get_room_by_id(db_session, test_room.id)
        assert room is not None
        assert room.id == test_room.id
        assert room.name == test_room.name
    
    def test_get_nonexistent_room(self, db_session):
        """Test getting non-existent room"""
        room = get_room_by_id(db_session, 99999)
        assert room is None
    
    def test_invite_user_to_room_success(self, db_session, test_room, test_user2):
        """Test successful user invitation to room"""
        invite_data = RoomInvite(user_id=test_user2.id)
        room = invite_user_to_room(db_session, test_room.id, invite_data, test_user.id)
        
        assert test_user2 in room.members
        assert len(room.members) == 2
    
    def test_invite_user_to_nonexistent_room(self, db_session, test_user2):
        """Test inviting user to non-existent room"""
        invite_data = RoomInvite(user_id=test_user2.id)
        
        with pytest.raises(HTTPException) as exc_info:
            invite_user_to_room(db_session, 99999, invite_data, 1)
        
        assert exc_info.value.status_code == 404
        assert "Room not found" in str(exc_info.value.detail)
    
    def test_invite_nonexistent_user(self, db_session, test_room, test_user):
        """Test inviting non-existent user"""
        invite_data = RoomInvite(user_id=99999)
        
        with pytest.raises(HTTPException) as exc_info:
            invite_user_to_room(db_session, test_room.id, invite_data, test_user.id)
        
        assert exc_info.value.status_code == 404
        assert "User not found" in str(exc_info.value.detail)
    
    def test_invite_user_already_in_room(self, db_session, test_room, test_user2):
        """Test inviting user who is already in room"""
        # First invite the user
        invite_data = RoomInvite(user_id=test_user2.id)
        invite_user_to_room(db_session, test_room.id, invite_data, test_user.id)
        
        # Try to invite again
        with pytest.raises(HTTPException) as exc_info:
            invite_user_to_room(db_session, test_room.id, invite_data, test_user.id)
        
        assert exc_info.value.status_code == 400
        assert "User is already in this room" in str(exc_info.value.detail)
    
    def test_send_message_success(self, db_session, test_room, test_user):
        """Test sending message successfully"""
        message_create = MessageCreate(content="Hello World!", room_id=test_room.id)
        message = send_message(db_session, message_create, test_user.id)
        
        assert message.content == "Hello World!"
        assert message.sender_id == test_user.id
        assert message.room_id == test_room.id
        assert message.sender.username == test_user.username
    
    def test_send_message_to_nonexistent_room(self, db_session, test_user):
        """Test sending message to non-existent room"""
        message_create = MessageCreate(content="Test", room_id=99999)
        
        with pytest.raises(HTTPException) as exc_info:
            send_message(db_session, message_create, test_user.id)
        
        assert exc_info.value.status_code == 404
        assert "Room not found" in str(exc_info.value.detail)
    
    def test_send_message_unauthorized(self, db_session, test_room, test_user2):
        """Test sending message without being in the room"""
        message_create = MessageCreate(content="Unauthorized message", room_id=test_room.id)
        
        with pytest.raises(HTTPException) as exc_info:
            send_message(db_session, message_create, test_user2.id)
        
        assert exc_info.value.status_code == 403
        assert "Not authorized to send message to this room" in str(exc_info.value.detail)
    
    def test_get_messages_by_room(self, db_session, test_room, test_user):
        """Test getting messages from room"""
        # Send a few messages first
        message_create1 = MessageCreate(content="Message 1", room_id=test_room.id)
        message_create2 = MessageCreate(content="Message 2", room_id=test_room.id)
        
        msg1 = send_message(db_session, message_create1, test_user.id)
        msg2 = send_message(db_session, message_create2, test_user.id)
        
        messages = get_messages_by_room(db_session, test_room.id)
        
        assert len(messages) == 2
        # Messages should be ordered by creation time (desc)
        assert messages[0].id == msg2.id
        assert messages[1].id == msg1.id
    
    def test_get_messages_from_nonexistent_room(self, db_session):
        """Test getting messages from non-existent room"""
        with pytest.raises(HTTPException) as exc_info:
            get_messages_by_room(db_session, 99999)
        
        assert exc_info.value.status_code == 404
        assert "Room not found" in str(exc_info.value.detail)
    
    def test_get_online_users(self, db_session, test_user, test_user2):
        """Test getting online users"""
        # Initially no users are online
        online_users = get_online_users(db_session)
        assert len(online_users) == 0
        
        # Set one user online
        set_user_online_status(db_session, test_user.id, True)
        online_users = get_online_users(db_session)
        assert len(online_users) == 1
        assert online_users[0].username == test_user.username
    
    def test_set_user_online_status(self, db_session, test_user):
        """Test setting user online status"""
        # Set user online
        user = set_user_online_status(db_session, test_user.id, True)
        assert user.is_online is True
        
        # Set user offline
        user = set_user_online_status(db_session, test_user.id, False)
        assert user.is_online is False
    
    def test_set_status_for_nonexistent_user(self, db_session):
        """Test setting status for non-existent user"""
        user = set_user_online_status(db_session, 99999, True)
        assert user is None