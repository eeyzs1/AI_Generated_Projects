from fastapi.testclient import TestClient
from tests.conftest import test_client


def test_send_message(test_client: TestClient):
    """测试发送消息"""
    # 注册用户
    test_client.post(
        "/register",
        json={
            "username": "messenger",
            "email": "message@example.com",
            "password": "password123"
        }
    )
    
    # 登录获取token
    login_response = test_client.post(
        "/login",
        json={
            "username": "messenger",
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
    
    # 发送消息
    response = test_client.post(
        "/messages",
        json={
            "content": "Hello, world!",
            "room_id": room_id
        },
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["content"] == "Hello, world!"
    assert data["room_id"] == room_id
    assert "id" in data


def test_get_room_messages(test_client: TestClient):
    """测试获取聊天室消息"""
    # 注册用户
    test_client.post(
        "/register",
        json={
            "username": "messageuser",
            "email": "messageuser@example.com",
            "password": "password123"
        }
    )
    
    # 登录获取token
    login_response = test_client.post(
        "/login",
        json={
            "username": "messageuser",
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
    
    # 发送消息
    test_client.post(
        "/messages",
        json={
            "content": "Hello, world!",
            "room_id": room_id
        },
        headers={"Authorization": f"Bearer {token}"}
    )
    
    # 获取聊天室消息
    response = test_client.get(
        f"/rooms/{room_id}/messages",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) > 0
    assert data[0]["content"] == "Hello, world!"