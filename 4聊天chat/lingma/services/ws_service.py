from fastapi import WebSocket
from typing import Dict, List
import json
from datetime import datetime

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, List[WebSocket]] = {}
        self.user_rooms: Dict[int, int] = {}  # user_id -> room_id mapping
    
    async def connect(self, websocket: WebSocket, user_id: int, room_id: int = None):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)
        
        if room_id:
            self.user_rooms[user_id] = room_id
            
        # Notify others that user is online
        await self.broadcast_user_status(user_id, True)
    
    def disconnect(self, websocket: WebSocket, user_id: int):
        if user_id in self.active_connections:
            self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:  # No more connections for this user
                del self.active_connections[user_id]
                if user_id in self.user_rooms:
                    del self.user_rooms[user_id]
                # Notify others that user is offline
                return True
        return False
    
    async def send_personal_message(self, message: str, user_id: int):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                await connection.send_text(message)
    
    async def broadcast_to_room(self, message: str, room_id: int, exclude_user: int = None):
        for user_id, connections in self.active_connections.items():
            if self.user_rooms.get(user_id) == room_id and user_id != exclude_user:
                for connection in connections:
                    await connection.send_text(message)
    
    async def broadcast_user_status(self, user_id: int, is_online: bool):
        status_message = json.dumps({
            "type": "user_status",
            "user_id": user_id,
            "is_online": is_online,
            "timestamp": datetime.now().isoformat()
        })
        
        # Broadcast to all connected users
        for connections in self.active_connections.values():
            for connection in connections:
                await connection.send_text(status_message)
    
    async def broadcast_message(self, message: str):
        """Broadcast message to all connected users"""
        for connections in self.active_connections.values():
            for connection in connections:
                await connection.send_text(message)

manager = ConnectionManager()