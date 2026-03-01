from typing import Dict, Set
from fastapi import WebSocket
import json


class ConnectionManager:
    """WebSocket连接管理器"""

    def __init__(self):
        # 存储所有活跃连接: {user_id: set of WebSocket connections}
        self.active_connections: Dict[int, Set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        """连接用户"""
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        self.active_connections[user_id].add(websocket)

    def disconnect(self, websocket: WebSocket, user_id: int):
        """断开用户连接"""
        if user_id in self.active_connections:
            self.active_connections[user_id].discard(websocket)
            # 如果该用户没有其他连接，删除用户记录
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_personal_message(self, message: dict, user_id: int):
        """发送个人消息"""
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_json(message)
                except:
                    # 连接已关闭，移除
                    self.active_connections[user_id].discard(connection)

    async def broadcast_to_room(self, message: dict, room_member_ids: list):
        """向聊天室所有成员广播消息"""
        for user_id in room_member_ids:
            await self.send_personal_message(message, user_id)

    async def broadcast_online_users(self, online_user_ids: list):
        """广播在线用户列表"""
        message = {
            "type": "online_users",
            "data": {"user_ids": online_user_ids}
        }
        # 向所有连接的用户广播
        for user_id, connections in self.active_connections.items():
            for connection in connections:
                try:
                    await connection.send_json(message)
                except:
                    self.active_connections[user_id].discard(connection)

    def get_online_users(self) -> list:
        """获取在线用户列表"""
        return list(self.active_connections.keys())


# 创建全局连接管理器实例
manager = ConnectionManager()
