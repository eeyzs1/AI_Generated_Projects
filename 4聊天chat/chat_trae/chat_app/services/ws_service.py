from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict, List, Optional
import json

class ConnectionManager:
    def __init__(self):
        # 存储活跃的WebSocket连接
        self.active_connections: Dict[int, WebSocket] = {}
        # 存储用户所在的房间
        self.user_rooms: Dict[int, List[int]] = {}
    
    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        self.active_connections[user_id] = websocket
        self.user_rooms[user_id] = []
    
    def disconnect(self, user_id: int):
        if user_id in self.active_connections:
            del self.active_connections[user_id]
        if user_id in self.user_rooms:
            del self.user_rooms[user_id]
    
    async def send_personal_message(self, message: str, user_id: int):
        if user_id in self.active_connections:
            await self.active_connections[user_id].send_text(message)
    
    async def broadcast_to_room(self, message: str, room_id: int, exclude_user: Optional[int] = None):
        for user_id, rooms in self.user_rooms.items():
            if room_id in rooms and user_id != exclude_user:
                if user_id in self.active_connections:
                    await self.active_connections[user_id].send_text(message)
    
    def add_user_to_room(self, user_id: int, room_id: int):
        if user_id not in self.user_rooms:
            self.user_rooms[user_id] = []
        if room_id not in self.user_rooms[user_id]:
            self.user_rooms[user_id].append(room_id)
    
    def remove_user_from_room(self, user_id: int, room_id: int):
        if user_id in self.user_rooms and room_id in self.user_rooms[user_id]:
            self.user_rooms[user_id].remove(room_id)
    
    def get_online_users(self) -> List[int]:
        return list(self.active_connections.keys())

# 创建连接管理器实例
manager = ConnectionManager()