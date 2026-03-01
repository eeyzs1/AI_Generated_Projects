import pytest


class TestUsers:
    """用户相关测试"""

    def test_get_all_users(self, client, auth_headers):
        """测试获取所有用户"""
        # 创建多个用户
        client.post("/api/auth/register", json={
            "username": "user1",
            "email": "user1@example.com",
            "password": "pass123"
        })
        client.post("/api/auth/register", json={
            "username": "user2",
            "email": "user2@example.com",
            "password": "pass123"
        })

        response = client.get("/api/users", headers=auth_headers)

        assert response.status_code == 200
        users = response.json()
        assert len(users) >= 2
        assert any(user["username"] == "user1" for user in users)
        assert any(user["username"] == "user2" for user in users)

    def test_get_users_without_auth(self, client):
        """测试未认证获取用户列表"""
        response = client.get("/api/users")

        assert response.status_code == 401

    def test_user_structure(self, client, auth_headers):
        """测试用户数据结构"""
        response = client.get("/api/users", headers=auth_headers)

        assert response.status_code == 200
        user = response.json()[0]
        assert "id" in user
        assert "username" in user
        assert "email" in user
        assert "is_online" in user
        assert "created_at" in user
        assert "hashed_password" not in user  # 不应返回密码
