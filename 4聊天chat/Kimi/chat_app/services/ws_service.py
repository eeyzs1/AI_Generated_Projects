from typing import Dict, List, Set
from fastapi import WebSocket
import json
from datetime import datetime


class WebSocketManager:
    """WebSocket连接管理器"""
    
    def __init__(self):
        # 存储用户连接: {user_id: WebSocket}
        self.active_connections: Dict[int, WebSocket] = {}
        # 存储房间连接: {room_id: Set[user_id]}
        self.room_connections: Dict[int, Set[int]] = {}
    
    async def connect(self, websocket: WebSocket, user_id: int):
        """建立WebSocket连接"""
        await websocket.accept()
        self.active_connections[user_id] = websocket
        print(f"用户 {user_id} 已连接")
    
    def disconnect(self, user_id: int):
        """断开WebSocket连接"""
        if user_id in self.active_connections:
            del self.active_connections[user_id]
        
        # 从所有房间中移除
        for room_id, members in self.room_connections.items():
            if user_id in members:
                members.remove(user_id)
        
        print(f"用户 {user_id} 已断开连接")
    
    async def join_room(self, user_id: int, room_id: int):
        """用户加入房间"""
        if room_id not in self.room_connections:
            self.room_connections[room_id] = set()
        self.room_connections[room_id].add(user_id)
        
        # 通知房间内其他用户
        await self.broadcast_to_room(
            room_id,
            {
                "type": "join",
                "data": {
                    "user_id": user_id,
                    "room_id": room_id,
                    "timestamp": datetime.now().isoformat()
                }
            },
            exclude_user=user_id
        )
    
    async def leave_room(self, user_id: int, room_id: int):
        """用户离开房间"""
        if room_id in self.room_connections:
            if user_id in self.room_connections[room_id]:
                self.room_connections[room_id].remove(user_id)
        
        # 通知房间内其他用户
        await self.broadcast_to_room(
            room_id,
            {
                "type": "leave",
                "data": {
                    "user_id": user_id,
                    "room_id": room_id,
                    "timestamp": datetime.now().isoformat()
                }
            },
            exclude_user=user_id
        )
    
    async def send_personal_message(self, user_id: int, message: dict):
        """发送个人消息"""
        if user_id in self.active_connections:
            websocket = self.active_connections[user_id]
            await websocket.send_json(message)
    
    async def broadcast_to_room(
        self,
        room_id: int,
        message: dict,
        exclude_user: int = None
    ):
        """广播消息到房间"""
        if room_id not in self.room_connections:
            return
        
        for user_id in self.room_connections[room_id]:
            if exclude_user and user_id == exclude_user:
                continue
            if user_id in self.active_connections:
                websocket = self.active_connections[user_id]
                await websocket.send_json(message)
    
    async def broadcast_to_all(self, message: dict, exclude_user: int = None):
        """广播消息给所有在线用户"""
        for user_id, websocket in self.active_connections.items():
            if exclude_user and user_id == exclude_user:
                continue
            await websocket.send_json(message)
    
    def get_online_user_ids(self) -> List[int]:
        """获取在线用户ID列表"""
        return list(self.active_connections.keys())
    
    def is_user_online(self, user_id: int) -> bool:
        """检查用户是否在线"""
        return user_id in self.active_connections
    
    async def notify_online_users_changed(self):
        """通知所有用户在线用户列表已更新"""
        online_users = self.get_online_user_ids()
        await self.broadcast_to_all({
            "type": "online_users_changed",
            "data": {
                "online_user_ids": online_users,
                "count": len(online_users)
            }
        })


# 全局WebSocket管理器实例
ws_manager = WebSocketManager()
