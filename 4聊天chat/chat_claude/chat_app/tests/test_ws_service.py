"""Unit tests for ConnectionManager (ws_service) — no HTTP, no DB needed."""
import asyncio
import pytest
from unittest.mock import AsyncMock, MagicMock
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.ws_service import ConnectionManager


def make_ws():
    ws = MagicMock()
    ws.send_json = AsyncMock()
    return ws


def run(coro):
    return asyncio.run(coro)


class TestConnectionManager:
    def setup_method(self):
        self.mgr = ConnectionManager()

    def test_add_connection_registers_user(self):
        ws = make_ws()
        run(self.mgr.add_connection(1, ws, 10, "alice"))
        assert ws in self.mgr.room_connections[1]
        assert self.mgr.usernames[10] == "alice"
        assert self.mgr.user_sessions[10] == 1
        assert self.mgr.websocket_user_map[ws] == 10

    def test_add_multiple_connections_same_room(self):
        ws1, ws2 = make_ws(), make_ws()
        run(self.mgr.add_connection(1, ws1, 10, "alice"))
        run(self.mgr.add_connection(1, ws2, 20, "bob"))
        assert len(self.mgr.room_connections[1]) == 2

    def test_add_same_user_multiple_tabs(self):
        ws1, ws2 = make_ws(), make_ws()
        run(self.mgr.add_connection(1, ws1, 10, "alice"))
        run(self.mgr.add_connection(1, ws2, 10, "alice"))
        assert self.mgr.user_sessions[10] == 2
        assert 10 in self.mgr.usernames

    def test_remove_connection_clears_user(self):
        ws = make_ws()
        run(self.mgr.add_connection(1, ws, 10, "alice"))
        self.mgr.remove_connection(1, ws)
        assert ws not in self.mgr.room_connections.get(1, set())
        assert 10 not in self.mgr.usernames
        assert 10 not in self.mgr.user_sessions

    def test_remove_one_tab_keeps_user_online(self):
        ws1, ws2 = make_ws(), make_ws()
        run(self.mgr.add_connection(1, ws1, 10, "alice"))
        run(self.mgr.add_connection(1, ws2, 10, "alice"))
        self.mgr.remove_connection(1, ws1)
        assert 10 in self.mgr.usernames
        assert self.mgr.user_sessions[10] == 1

    def test_get_online_users(self):
        ws1, ws2 = make_ws(), make_ws()
        run(self.mgr.add_connection(1, ws1, 10, "alice"))
        run(self.mgr.add_connection(1, ws2, 20, "bob"))
        users = self.mgr.get_online_users()
        ids = {u["id"] for u in users}
        assert ids == {10, 20}

    def test_broadcast_room_sends_to_all(self):
        ws1, ws2 = make_ws(), make_ws()
        run(self.mgr.add_connection(1, ws1, 10, "alice"))
        run(self.mgr.add_connection(1, ws2, 20, "bob"))
        run(self.mgr.broadcast_room(1, {"type": "ping"}))
        ws1.send_json.assert_awaited_once_with({"type": "ping"})
        ws2.send_json.assert_awaited_once_with({"type": "ping"})

    def test_broadcast_room_skips_failed_connections(self):
        ws1, ws2 = make_ws(), make_ws()
        ws1.send_json = AsyncMock(side_effect=Exception("disconnected"))
        run(self.mgr.add_connection(1, ws1, 10, "alice"))
        run(self.mgr.add_connection(1, ws2, 20, "bob"))
        run(self.mgr.broadcast_room(1, {"type": "ping"}))
        ws2.send_json.assert_awaited_once_with({"type": "ping"})

    def test_broadcast_empty_room_no_error(self):
        run(self.mgr.broadcast_room(999, {"type": "ping"}))

    def test_remove_unknown_websocket_no_error(self):
        ws = make_ws()
        self.mgr.remove_connection(1, ws)
