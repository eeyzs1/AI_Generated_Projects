from __future__ import annotations

from typing import Dict, List, Set

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self.room_connections: Dict[int, Set[WebSocket]] = {}
        self.user_sessions: Dict[int, int] = {}
        self.usernames: Dict[int, str] = {}
        self.websocket_user_map: Dict[WebSocket, int] = {}

    def add_connection(self, room_id: int, websocket: WebSocket, user_id: int, username: str) -> None:
        self.room_connections.setdefault(room_id, set()).add(websocket)
        self.websocket_user_map[websocket] = user_id
        self.user_sessions[user_id] = self.user_sessions.get(user_id, 0) + 1
        self.usernames[user_id] = username

    def remove_connection(self, room_id: int, websocket: WebSocket) -> None:
        room = self.room_connections.get(room_id)
        user_id = self.websocket_user_map.pop(websocket, None)
        if room and websocket in room:
            room.remove(websocket)
            if not room:
                self.room_connections.pop(room_id, None)
        if user_id is not None:
            self.user_sessions[user_id] = max(0, self.user_sessions.get(user_id, 1) - 1)
            if self.user_sessions[user_id] == 0:
                self.user_sessions.pop(user_id, None)
                self.usernames.pop(user_id, None)

    async def broadcast_room(self, room_id: int, payload: dict) -> None:
        connections = self.room_connections.get(room_id, set())
        for connection in list(connections):
            try:
                await connection.send_json(payload)
            except Exception:
                self.remove_connection(room_id, connection)

    def get_online_users(self) -> List[dict]:
        return [
            {"id": user_id, "username": self.usernames[user_id]}
            for user_id in sorted(self.user_sessions.keys())
        ]


manager = ConnectionManager()
