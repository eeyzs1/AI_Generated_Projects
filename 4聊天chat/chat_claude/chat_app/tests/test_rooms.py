"""Tests for chat room endpoints."""
import pytest
from helpers import register_and_login, auth_headers


class TestCreateRoom:
    def test_create_room_success(self, client):
        token = register_and_login(client, "alice")
        resp = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token))
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "general"
        assert len(data["members"]) == 1
        assert data["members"][0]["username"] == "alice"

    def test_create_room_duplicate_name(self, client):
        token = register_and_login(client, "alice")
        client.post("/rooms", json={"name": "general"}, headers=auth_headers(token))
        resp = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token))
        assert resp.status_code == 400
        assert "already exists" in resp.json()["detail"]

    def test_create_room_requires_auth(self, client):
        resp = client.post("/rooms", json={"name": "general"})
        assert resp.status_code == 401


class TestListRooms:
    def test_list_rooms(self, client):
        token = register_and_login(client, "alice")
        client.post("/rooms", json={"name": "room1"}, headers=auth_headers(token))
        client.post("/rooms", json={"name": "room2"}, headers=auth_headers(token))
        resp = client.get("/rooms", headers=auth_headers(token))
        assert resp.status_code == 200
        names = [r["name"] for r in resp.json()]
        assert "room1" in names
        assert "room2" in names

    def test_list_rooms_empty(self, client):
        token = register_and_login(client, "alice")
        resp = client.get("/rooms", headers=auth_headers(token))
        assert resp.status_code == 200
        assert resp.json() == []


class TestJoinRoom:
    def test_join_room_success(self, client):
        token_a = register_and_login(client, "alice")
        token_b = register_and_login(client, "bob")
        room = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token_a)).json()
        resp = client.post(f"/rooms/{room['id']}/join", headers=auth_headers(token_b))
        assert resp.status_code == 200
        usernames = [m["username"] for m in resp.json()["members"]]
        assert "bob" in usernames

    def test_join_room_already_member(self, client):
        token = register_and_login(client, "alice")
        room = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token)).json()
        # Joining again should be idempotent
        resp = client.post(f"/rooms/{room['id']}/join", headers=auth_headers(token))
        assert resp.status_code == 200
        assert len(resp.json()["members"]) == 1

    def test_join_nonexistent_room(self, client):
        token = register_and_login(client, "alice")
        resp = client.post("/rooms/9999/join", headers=auth_headers(token))
        assert resp.status_code == 404
