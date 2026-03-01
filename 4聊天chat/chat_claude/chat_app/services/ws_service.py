from typing import Dict, Set
from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.room_connections: Dict[int, Set[WebSocket]] = {}
        self.user_sessions: Dict[int, int] = {}  # user_id -> ref count
        self.usernames: Dict[int, str] = {}
        self.websocket_user_map: Dict[WebSocket, int] = {}

    async def add_connection(self, room_id: int, websocket: WebSocket, user_id: int, username: str):
        if room_id not in self.room_connections:
            self.room_connections[room_id] = set()
        self.room_connections[room_id].add(websocket)
        self.websocket_user_map[websocket] = user_id
        self.usernames[user_id] = username
        self.user_sessions[user_id] = self.user_sessions.get(user_id, 0) + 1

    def remove_connection(self, room_id: int, websocket: WebSocket):
        user_id = self.websocket_user_map.pop(websocket, None)
        if room_id in self.room_connections:
            self.room_connections[room_id].discard(websocket)
        if user_id is not None:
            count = self.user_sessions.get(user_id, 1) - 1
            if count <= 0:
                self.user_sessions.pop(user_id, None)
                self.usernames.pop(user_id, None)
            else:
                self.user_sessions[user_id] = count

    async def broadcast_room(self, room_id: int, data: dict):
        conns = self.room_connections.get(room_id, set()).copy()
        for ws in conns:
            try:
                await ws.send_json(data)
            except Exception:
                pass

    def get_online_users(self):
        return [{"id": uid, "username": uname} for uid, uname in self.usernames.items()]


manager = ConnectionManager()
