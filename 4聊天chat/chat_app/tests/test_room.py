from fastapi.testclient import TestClient
from tests.conftest import test_client


def test_create_room(test_client: TestClient):
    """测试创建聊天室"""
    # 注册用户
    test_client.post(
        "/register",
        json={
            "username": "roomcreator",
            "email": "room@example.com",
            "password": "password123"
        }
    )
    
    # 登录获取token
    login_response = test_client.post(
        "/login",
        json={
            "username": "roomcreator",
            "password": "password123"
        }
    )
    token = login_response.json()["access_token"]
    
    # 创建聊天室
    response = test_client.post(
        "/rooms",
        json={"name": "Test Room"},
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Test Room"
    assert "id" in data


def test_get_rooms(test_client: TestClient):
    """测试获取用户的聊天室列表"""
    # 注册用户
    test_client.post(
        "/register",
        json={
            "username": "roomuser",
            "email": "roomuser@example.com",
            "password": "password123"
        }
    )
    
    # 登录获取token
    login_response = test_client.post(
        "/login",
        json={
            "username": "roomuser",
            "password": "password123"
        }
    )
    token = login_response.json()["access_token"]
    
    # 创建聊天室
    test_client.post(
        "/rooms",
        json={"name": "Test Room 1"},
        headers={"Authorization": f"Bearer {token}"}
    )
    
    # 获取聊天室列表
    response = test_client.get(
        "/rooms",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) > 0


def test_add_user_to_room(test_client: TestClient):
    """测试添加用户到聊天室"""
    # 注册两个用户
    test_client.post(
        "/register",
        json={
            "username": "roomowner",
            "email": "owner@example.com",
            "password": "password123"
        }
    )
    test_client.post(
        "/register",
        json={
            "username": "roommember",
            "email": "member@example.com",
            "password": "password123"
        }
    )
    
    # 登录获取token
    login_response = test_client.post(
        "/login",
        json={
            "username": "roomowner",
            "password": "password123"
        }
    )
    token = login_response.json()["access_token"]
    
    # 创建聊天室
    room_response = test_client.post(
        "/rooms",
        json={"name": "Test Room"},
        headers={"Authorization": f"Bearer {token}"}
    )
    room_id = room_response.json()["id"]
    
    # 添加用户到聊天室
    response = test_client.post(
        f"/rooms/{room_id}/add/2",  # 假设第二个用户ID为2
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["detail"] == "User added to room successfully"