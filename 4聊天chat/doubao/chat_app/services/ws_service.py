from typing import Dict, Set
from fastapi import WebSocket, WebSocketDisconnect

# 存储在线用户连接：{user_id: WebSocket}
online_users: Dict[int, WebSocket] = {}
# 存储房间连接：{room_id: Set[WebSocket]}
room_connections: Dict[int, Set[WebSocket]] = {}

# 用户上线
async def user_online(user_id: int, websocket: WebSocket):
    online_users[user_id] = websocket
    # 广播在线用户列表
    await broadcast_online_users()

# 用户下线
async def user_offline(user_id: int):
    if user_id in online_users:
        del online_users[user_id]
    # 广播在线用户列表
    await broadcast_online_users()

# 加入房间
async def join_room(room_id: int, websocket: WebSocket):
    if room_id not in room_connections:
        room_connections[room_id] = set()
    room_connections[room_id].add(websocket)

# 离开房间
async def leave_room(room_id: int, websocket: WebSocket):
    if room_id in room_connections:
        room_connections[room_id].discard(websocket)
        if not room_connections[room_id]:
            del room_connections[room_id]

# 广播房间消息
async def broadcast_room_message(room_id: int, message: dict):
    if room_id in room_connections:
        for connection in room_connections[room_id]:
            await connection.send_json(message)

# 广播在线用户列表
async def broadcast_online_users():
    online_user_ids = list(online_users.keys())
    message = {
        "type": "online_users",
        "data": online_user_ids
    }
    for connection in online_users.values():
        await connection.send_json(message)

# WebSocket消息处理
async def handle_websocket_message(websocket: WebSocket, message: dict, user_id: int):
    msg_type = message.get("type")
    
    if msg_type == "join_room":
        room_id = message.get("room_id")
        if room_id:
            await join_room(room_id, websocket)
    
    elif msg_type == "leave_room":
        room_id = message.get("room_id")
        if room_id:
            await leave_room(room_id, websocket)
    
    elif msg_type == "send_message":
        room_id = message.get("room_id")
        content = message.get("content")
        if room_id and content:
            # 构造消息数据
            message_data = {
                "type": "new_message",
                "data": {
                    "sender_id": user_id,
                    "room_id": room_id,
                    "content": content,
                    "created_at": message.get("created_at")
                }
            }
            # 广播消息
            await broadcast_room_message(room_id, message_data)
