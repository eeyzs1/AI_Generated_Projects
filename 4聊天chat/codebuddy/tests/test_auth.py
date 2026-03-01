import pytest


class TestAuth:
    """认证相关测试"""

    def test_register_user(self, client):
        """测试用户注册"""
        response = client.post("/api/auth/register", json={
            "username": "newuser",
            "email": "newuser@example.com",
            "password": "password123"
        })

        assert response.status_code == 201
        data = response.json()
        assert data["username"] == "newuser"
        assert data["email"] == "newuser@example.com"
        assert "id" in data
        assert "hashed_password" not in data  # 不应返回密码

    def test_register_duplicate_username(self, client, test_user_data):
        """测试注册重复用户名"""
        client.post("/api/auth/register", json=test_user_data)

        response = client.post("/api/auth/register", json={
            "username": test_user_data["username"],
            "email": "different@example.com",
            "password": "password123"
        })

        assert response.status_code == 400
        assert "already registered" in response.json()["detail"]

    def test_register_duplicate_email(self, client, test_user_data):
        """测试注册重复邮箱"""
        client.post("/api/auth/register", json=test_user_data)

        response = client.post("/api/auth/register", json={
            "username": "differentuser",
            "email": test_user_data["email"],
            "password": "password123"
        })

        assert response.status_code == 400
        assert "already registered" in response.json()["detail"]

    def test_login_success(self, client, test_user_data):
        """测试成功登录"""
        client.post("/api/auth/register", json=test_user_data)

        response = client.post("/api/auth/login", json={
            "username": test_user_data["username"],
            "password": test_user_data["password"]
        })

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    def test_login_wrong_password(self, client, test_user_data):
        """测试错误密码登录"""
        client.post("/api/auth/register", json=test_user_data)

        response = client.post("/api/auth/login", json={
            "username": test_user_data["username"],
            "password": "wrongpassword"
        })

        assert response.status_code == 401
        assert "Incorrect username or password" in response.json()["detail"]

    def test_login_nonexistent_user(self, client):
        """测试不存在用户登录"""
        response = client.post("/api/auth/login", json={
            "username": "nonexistent",
            "password": "password123"
        })

        assert response.status_code == 401
        assert "Incorrect username or password" in response.json()["detail"]

    def test_get_current_user(self, client, auth_headers):
        """测试获取当前用户信息"""
        response = client.get("/api/auth/me", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert "username" in data
        assert "email" in data
        assert "id" in data

    def test_get_current_user_without_token(self, client):
        """测试未认证获取用户信息"""
        response = client.get("/api/auth/me")

        assert response.status_code == 401

    def test_get_current_user_invalid_token(self, client):
        """测试无效token获取用户信息"""
        response = client.get("/api/auth/me", headers={
            "Authorization": "Bearer invalid_token"
        })

        assert response.status_code == 401
