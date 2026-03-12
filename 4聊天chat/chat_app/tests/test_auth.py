from fastapi.testclient import TestClient
from tests.conftest import test_client


def test_register(test_client: TestClient):
    """测试用户注册"""
    response = test_client.post(
        "/register",
        json={
            "username": "testuser",
            "email": "test@example.com",
            "password": "password123"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "testuser"
    assert data["email"] == "test@example.com"
    assert "id" in data


def test_login(test_client: TestClient):
    """测试用户登录"""
    # 先注册用户
    test_client.post(
        "/register",
        json={
            "username": "testlogin",
            "email": "login@example.com",
            "password": "password123"
        }
    )
    
    # 登录
    response = test_client.post(
        "/login",
        json={
            "username": "testlogin",
            "password": "password123"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


def test_get_current_user(test_client: TestClient):
    """测试获取当前用户信息"""
    # 注册用户
    test_client.post(
        "/register",
        json={
            "username": "testcurrent",
            "email": "current@example.com",
            "password": "password123"
        }
    )
    
    # 登录获取token
    login_response = test_client.post(
        "/login",
        json={
            "username": "testcurrent",
            "password": "password123"
        }
    )
    token = login_response.json()["access_token"]
    
    # 获取当前用户信息
    response = test_client.get(
        "/users/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "testcurrent"
    assert data["email"] == "current@example.com"