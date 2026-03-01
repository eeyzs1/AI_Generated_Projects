import pytest


class TestRooms:
    """聊天室相关测试"""

    def test_create_room(self, client, auth_headers):
        """测试创建聊天室"""
        response = client.post("/api/rooms", headers=auth_headers, json={
            "name": "测试聊天室"
        })

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "测试聊天室"
        assert "id" in data
        assert "creator_id" in data

    def test_create_room_without_auth(self, client):
        """测试未认证创建聊天室"""
        response = client.post("/api/rooms", json={
            "name": "测试聊天室"
        })

        assert response.status_code == 401

    def test_get_user_rooms(self, client, auth_headers):
        """测试获取用户聊天室列表"""
        # 创建聊天室
        client.post("/api/rooms", headers=auth_headers, json={
            "name": "聊天室1"
        })
        client.post("/api/rooms", headers=auth_headers, json={
            "name": "聊天室2"
        })

        response = client.get("/api/rooms", headers=auth_headers)

        assert response.status_code == 200
        rooms = response.json()
        assert len(rooms) >= 2
        assert any(room["name"] == "聊天室1" for room in rooms)
        assert any(room["name"] == "聊天室2" for room in rooms)

    def test_get_room_detail(self, client, auth_headers):
        """测试获取聊天室详情"""
        # 创建聊天室
        create_response = client.post("/api/rooms", headers=auth_headers, json={
            "name": "测试聊天室"
        })
        room_id = create_response.json()["id"]

        response = client.get(f"/api/rooms/{room_id}", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == room_id
        assert data["name"] == "测试聊天室"
        assert "members" in data
        assert "creator_id" in data

    def test_get_nonexistent_room(self, client, auth_headers):
        """测试获取不存在的聊天室"""
        response = client.get("/api/rooms/99999", headers=auth_headers)

        assert response.status_code == 404

    def test_add_member_to_room(self, client, auth_headers, test_user_data):
        """测试添加成员到聊天室"""
        # 创建聊天室
        create_response = client.post("/api/rooms", headers=auth_headers, json={
            "name": "测试聊天室"
        })
        room_id = create_response.json()["id"]

        # 创建另一个用户
        client.post("/api/auth/register", json={
            "username": "memberuser",
            "email": "member@example.com",
            "password": "pass123"
        })
        users_response = client.get("/api/users", headers=auth_headers)
        member_id = next(u["id"] for u in users_response.json() if u["username"] == "memberuser")

        # 添加成员
        response = client.post("/api/rooms/members", headers=auth_headers, json={
            "room_id": room_id,
            "user_id": member_id
        })

        assert response.status_code == 200
        assert response.json()["message"] == "Member added successfully"

    def test_add_member_without_auth(self, client):
        """测试未认证添加成员"""
        response = client.post("/api/rooms/members", json={
            "room_id": 1,
            "user_id": 2
        })

        assert response.status_code == 401

    def test_add_member_to_nonexistent_room(self, client, auth_headers):
        """测试添加成员到不存在的聊天室"""
        response = client.post("/api/rooms/members", headers=auth_headers, json={
            "room_id": 99999,
            "user_id": 1
        })

        assert response.status_code == 404

    def test_add_nonexistent_user(self, client, auth_headers):
        """测试添加不存在的用户"""
        # 创建聊天室
        create_response = client.post("/api/rooms", headers=auth_headers, json={
            "name": "测试聊天室"
        })
        room_id = create_response.json()["id"]

        response = client.post("/api/rooms/members", headers=auth_headers, json={
            "room_id": room_id,
            "user_id": 99999
        })

        assert response.status_code == 404

    def test_add_duplicate_member(self, client, auth_headers):
        """测试添加重复成员"""
        # 创建聊天室
        create_response = client.post("/api/rooms", headers=auth_headers, json={
            "name": "测试聊天室"
        })
        room_id = create_response.json()["id"]

        # 获取当前用户ID
        me_response = client.get("/api/auth/me", headers=auth_headers)
        user_id = me_response.json()["id"]

        # 创建者已经在房间中，再次添加应该失败
        response = client.post("/api/rooms/members", headers=auth_headers, json={
            "room_id": room_id,
            "user_id": user_id
        })

        assert response.status_code == 400
