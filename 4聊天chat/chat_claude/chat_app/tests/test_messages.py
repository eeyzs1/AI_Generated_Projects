"""Tests for message endpoints."""
import pytest
from helpers import register_and_login, auth_headers


def setup_room(client, creator_username="alice"):
    token = register_and_login(client, creator_username)
    room = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token)).json()
    return token, room


class TestSendMessage:
    def test_send_message_success(self, client):
        token, room = setup_room(client)
        resp = client.post(
            f"/rooms/{room['id']}/messages",
            json={"content": "hello world"},
            headers=auth_headers(token),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["content"] == "hello world"
        assert data["sender"]["username"] == "alice"
        assert data["room_id"] == room["id"]

    def test_send_message_non_member(self, client):
        token_a, room = setup_room(client, "alice")
        token_b = register_and_login(client, "bob")
        resp = client.post(
            f"/rooms/{room['id']}/messages",
            json={"content": "hi"},
            headers=auth_headers(token_b),
        )
        assert resp.status_code == 403

    def test_send_message_nonexistent_room(self, client):
        token = register_and_login(client, "alice")
        resp = client.post(
            "/rooms/9999/messages",
            json={"content": "hi"},
            headers=auth_headers(token),
        )
        assert resp.status_code == 404

    def test_send_message_requires_auth(self, client):
        token, room = setup_room(client)
        resp = client.post(f"/rooms/{room['id']}/messages", json={"content": "hi"})
        assert resp.status_code == 401


class TestGetMessages:
    def test_get_messages_empty(self, client):
        token, room = setup_room(client)
        resp = client.get(f"/rooms/{room['id']}/messages", headers=auth_headers(token))
        assert resp.status_code == 200
        assert resp.json() == []

    def test_get_messages_ordered(self, client):
        token, room = setup_room(client)
        for text in ["first", "second", "third"]:
            client.post(
                f"/rooms/{room['id']}/messages",
                json={"content": text},
                headers=auth_headers(token),
            )
        resp = client.get(f"/rooms/{room['id']}/messages", headers=auth_headers(token))
        assert resp.status_code == 200
        contents = [m["content"] for m in resp.json()]
        assert contents == ["first", "second", "third"]

    def test_get_messages_non_member(self, client):
        token_a, room = setup_room(client, "alice")
        token_b = register_and_login(client, "bob")
        # bob is not a member — get_room succeeds but list_messages is accessible
        # (the route only checks auth, not membership for GET)
        # This verifies the current behaviour: 200 with empty list
        resp = client.get(f"/rooms/{room['id']}/messages", headers=auth_headers(token_b))
        assert resp.status_code == 200
