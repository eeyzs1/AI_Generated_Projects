"""Integration tests for the WebSocket endpoint."""
import json
import pytest
from helpers import register_and_login, auth_headers


class TestWebSocket:
    def test_ws_invalid_token_closes(self, client):
        from starlette.websockets import WebSocketDisconnect
        with pytest.raises(WebSocketDisconnect) as exc_info:
            with client.websocket_connect("/ws/rooms/1?token=bad.token"):
                pass
        assert exc_info.value.code == 4001

    def test_ws_connect_and_receive_history(self, client):
        token = register_and_login(client, "alice")
        room = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token)).json()

        with client.websocket_connect(f"/ws/rooms/{room['id']}?token={token}") as ws:
            msg = ws.receive_json()
            assert msg["type"] == "history"
            assert isinstance(msg["messages"], list)

    def test_ws_receives_users_event_on_connect(self, client):
        token = register_and_login(client, "alice")
        room = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token)).json()

        with client.websocket_connect(f"/ws/rooms/{room['id']}?token={token}") as ws:
            ws.receive_json()  # history
            users_msg = ws.receive_json()
            assert users_msg["type"] == "users"
            usernames = [u["username"] for u in users_msg["users"]]
            assert "alice" in usernames

    def test_ws_send_and_receive_message(self, client):
        token = register_and_login(client, "alice")
        room = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token)).json()

        with client.websocket_connect(f"/ws/rooms/{room['id']}?token={token}") as ws:
            ws.receive_json()  # history
            ws.receive_json()  # users

            ws.send_text(json.dumps({"content": "hello ws"}))
            msg = ws.receive_json()
            assert msg["type"] == "message"
            assert msg["content"] == "hello ws"
            assert msg["sender"]["username"] == "alice"

    def test_ws_empty_content_ignored(self, client):
        token = register_and_login(client, "alice")
        room = client.post("/rooms", json={"name": "general"}, headers=auth_headers(token)).json()

        with client.websocket_connect(f"/ws/rooms/{room['id']}?token={token}") as ws:
            ws.receive_json()  # history
            ws.receive_json()  # users

            ws.send_text(json.dumps({"content": "   "}))
            # No message broadcast — send a real message to confirm connection still alive
            ws.send_text(json.dumps({"content": "real"}))
            msg = ws.receive_json()
            assert msg["type"] == "message"
            assert msg["content"] == "real"
