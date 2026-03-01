from typing import Dict, List
import asyncio
import json

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List] = {}
        self.user_rooms: Dict[str, List[str]] = {}

    async def connect(self, websocket, username: str):
        await websocket.accept()
        
        # Initialize user's room list if not exists
        if username not in self.user_rooms:
            self.user_rooms[username] = []
        
        # Add connection to user's connections
        if username not in self.active_connections:
            self.active_connections[username] = []
        self.active_connections[username].append(websocket)

    def disconnect(self, websocket, username: str):
        if username in self.active_connections:
            self.active_connections[username].remove(websocket)
            if not self.active_connections[username]:
                del self.active_connections[username]
        
        # Remove user from all rooms when they disconnect
        if username in self.user_rooms:
            for room in self.user_rooms[username]:
                if room in self.active_connections:
                    # Notify other users in room that this user left
                    asyncio.create_task(
                        self.broadcast_to_room(
                            room_name=room,
                            message={
                                "type": "user_left",
                                "user": username,
                                "room": room
                            }
                        )
                    )
            del self.user_rooms[username]

    async def broadcast_to_room(self, room_name: str, message: dict):
        """Broadcast a message to all users in a specific room"""
        for username, connections in self.active_connections.items():
            if username in self.user_rooms and room_name in self.user_rooms[username]:
                for connection in connections:
                    try:
                        await connection.send_text(json.dumps(message))
                    except:
                        # If sending fails, remove the connection
                        self.disconnect(connection, username)

    async def send_personal_message(self, message: str, websocket):
        await websocket.send_text(message)

    def add_user_to_room(self, room_name: str, username: str):
        """Add a user to a room"""
        if username not in self.user_rooms:
            self.user_rooms[username] = []
        if room_name not in self.user_rooms[username]:
            self.user_rooms[username].append(room_name)

    def remove_user_from_room(self, room_name: str, username: str):
        """Remove a user from a room"""
        if username in self.user_rooms and room_name in self.user_rooms[username]:
            self.user_rooms[username].remove(room_name)

    async def broadcast_online_users(self):
        """Broadcast updated online users list to all connected users"""
        online_users = list(self.active_connections.keys())
        message = {
            "type": "online_users_update",
            "users": online_users
        }
        
        for connections in self.active_connections.values():
            for connection in connections:
                try:
                    await connection.send_text(json.dumps(message))
                except:
                    continue
