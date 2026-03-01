import pytest
from sqlalchemy.orm import Session
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services import (
    create_user, authenticate_user, create_room, create_message,
    is_room_member, get_all_users, get_user_by_username, update_user_online_status
)
from schemas import UserCreate, RoomCreate, MessageCreate


class TestAuthService:
    """认证服务测试"""

    def test_create_user(self, db: Session):
        """测试创建用户"""
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpass123"
        )
        user = create_user(db, user_data)

        assert user.id is not None
        assert user.username == "testuser"
        assert user.email == "test@example.com"
        assert user.hashed_password is not None
        assert user.hashed_password != "testpass123"  # 应该被加密

    def test_authenticate_user_success(self, db: Session):
        """测试成功认证用户"""
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpass123"
        )
        create_user(db, user_data)

        authenticated = authenticate_user(db, "testuser", "testpass123")

        assert authenticated is not None
        assert authenticated.username == "testuser"

    def test_authenticate_user_wrong_password(self, db: Session):
        """测试错误密码认证"""
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpass123"
        )
        create_user(db, user_data)

        authenticated = authenticate_user(db, "testuser", "wrongpassword")

        assert authenticated is None

    def test_get_user_by_username(self, db: Session):
        """测试根据用户名获取用户"""
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpass123"
        )
        created_user = create_user(db, user_data)

        user = get_user_by_username(db, "testuser")

        assert user is not None
        assert user.id == created_user.id

    def test_update_user_online_status(self, db: Session):
        """测试更新用户在线状态"""
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpass123"
        )
        user = create_user(db, user_data)

        # 更新为在线
        success = update_user_online_status(db, user.id, 1)
        assert success is True

        db.refresh(user)
        assert user.is_online == 1

        # 更新为离线
        success = update_user_online_status(db, user.id, 0)
        assert success is True

        db.refresh(user)
        assert user.is_online == 0


class TestChatService:
    """聊天服务测试"""

    def test_create_room(self, db: Session):
        """测试创建聊天室"""
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpass123"
        )
        user = create_user(db, user_data)

        room_data = RoomCreate(name="测试聊天室")
        room = create_room(db, room_data, user.id)

        assert room.id is not None
        assert room.name == "测试聊天室"
        assert room.creator_id == user.id

    def test_create_message(self, db: Session):
        """测试创建消息"""
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpass123"
        )
        user = create_user(db, user_data)

        room_data = RoomCreate(name="测试聊天室")
        room = create_room(db, room_data, user.id)

        message_data = MessageCreate(
            room_id=room.id,
            content="测试消息"
        )
        message = create_message(db, message_data, user.id)

        assert message.id is not None
        assert message.content == "测试消息"
        assert message.sender_id == user.id
        assert message.room_id == room.id

    def test_is_room_member(self, db: Session):
        """测试检查聊天室成员"""
        user_data = UserCreate(
            username="testuser",
            email="test@example.com",
            password="testpass123"
        )
        user = create_user(db, user_data)

        room_data = RoomCreate(name="测试聊天室")
        room = create_room(db, room_data, user.id)

        # 创建者应该是成员
        is_member = is_room_member(db, room.id, user.id)
        assert is_member is True

        # 非成员用户
        is_member = is_room_member(db, room.id, 999)
        assert is_member is False

    def test_get_all_users(self, db: Session):
        """测试获取所有用户"""
        create_user(db, UserCreate(
            username="user1",
            email="user1@example.com",
            password="pass123"
        ))
        create_user(db, UserCreate(
            username="user2",
            email="user2@example.com",
            password="pass123"
        ))

        users = get_all_users(db)

        assert len(users) >= 2
        assert any(u.username == "user1" for u in users)
        assert any(u.username == "user2" for u in users)
