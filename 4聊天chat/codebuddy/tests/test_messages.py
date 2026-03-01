import pytest


class TestMessages:
    """消息相关测试"""

    def test_get_room_messages(self, client, auth_headers):
        """测试获取聊天室消息"""
        # 创建聊天室
        create_response = client.post("/api/rooms", headers=auth_headers, json={
            "name": "测试聊天室"
        })
        room_id = create_response.json()["id"]

        response = client.get(f"/api/rooms/{room_id}/messages", headers=auth_headers)

        assert response.status_code == 200
        messages = response.json()
        assert isinstance(messages, list)

    def test_get_messages_from_nonexistent_room(self, client, auth_headers):
        """测试获取不存在聊天室的消息"""
        response = client.get("/api/rooms/99999/messages", headers=auth_headers)

        assert response.status_code == 403  # 不是成员

    def test_get_messages_without_auth(self, client):
        """测试未认证获取消息"""
        response = client.get("/api/rooms/1/messages")

        assert response.status_code == 401

    def test_message_structure(self, client, auth_headers):
        """测试消息数据结构"""
        # 创建聊天室
        create_response = client.post("/api/rooms", headers=auth_headers, json={
            "name": "测试聊天室"
        })
        room_id = create_response.json()["id"]

        response = client.get(f"/api/rooms/{room_id}/messages", headers=auth_headers)

        assert response.status_code == 200
        messages = response.json()
        # 空列表也是有效的
        for message in messages:
            assert "id" in message
            assert "room_id" in message
            assert "sender_id" in message
            assert "content" in message
            assert "created_at" in message
