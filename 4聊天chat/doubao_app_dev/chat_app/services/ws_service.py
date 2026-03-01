from typing import Dict, List, Set
from fastapi import WebSocket, WebSocketDisconnect, Depends, HTTPException
from sqlalchemy.orm import Session
import json

from ..database import get_db
from ..models.room import Room, RoomMember
from ..models.user import User
from ..schemas.message import WebSocketMessage
from .auth_service import get_current_user
from jose import JWTError, jwt
from ..schemas.user import TokenData

# 存储活动的WebSocket连接
# room_id -> set of (websocket, user_id)
room_connections: Dict[int, Set[tuple[WebSocket, int]]] = {}
# user_id -> websocket
user_connections: Dict[int, WebSocket] = {}
# 在线用户列表
online_users: Set[int] = set()

# JWT密钥和算法（与auth_service.py保持一致）
SECRET_KEY = "your-secret-key"
ALGORITHM = "HS256"

async def get_current_user_ws(websocket: WebSocket, db: Session) -> User:
    """从WebSocket连接中获取当前用户"""
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008, reason="Missing authentication token")
        raise HTTPException(status_code=401, detail="Missing authentication token")
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            await websocket.close(code=1008, reason="Invalid authentication token")
            raise HTTPException(status_code=401, detail="Invalid authentication token")
        token_data = TokenData(username=username)
    except JWTError:
        await websocket.close(code=1008, reason="Invalid authentication token")
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    
    user = db.query(User).filter(User.username == token_data.username).first()
    if user is None:
        await websocket.close(code=1008, reason="User not found")
        raise HTTPException(status_code=404, detail="User not found")
    
    return user

async def connect_to_room(websocket: WebSocket, room_id: int, user_id: int):
    """连接到聊天室"""
    if room_id not in room_connections:
        room_connections[room_id] = set()
    
    room_connections[room_id].add((websocket, user_id))
    
    # 通知聊天室其他成员有新用户加入
    await broadcast_user_joined(room_id, user_id)

async def disconnect_from_room(websocket: WebSocket, room_id: int, user_id: int):
    """从聊天室断开连接"""
    if room_id in room_connections:
        room_connections[room_id].discard((websocket, user_id))
        
        # 如果聊天室没有连接了，删除聊天室
        if not room_connections[room_id]:
            del room_connections[room_id]
        else:
            # 通知聊天室其他成员有用户离开
            await broadcast_user_left(room_id, user_id)

async def broadcast_message(room_id: int, message: dict):
    """向聊天室广播消息"""
    if room_id in room_connections:
        for connection, _ in room_connections[room_id]:
            await connection.send_json(message)

async def broadcast_user_joined(room_id: int, user_id: int):
    """广播用户加入聊天室"""
    message = {
        "type": "user_joined",
        "data": {
            "user_id": user_id
        }
    }
    await broadcast_message(room_id, message)

async def broadcast_user_left(room_id: int, user_id: int):
    """广播用户离开聊天室"""
    message = {
        "type": "user_left",
        "data": {
            "user_id": user_id
        }
    }
    await broadcast_message(room_id, message)

async def connect_user(websocket: WebSocket, user_id: int):
    """连接用户"""
    user_connections[user_id] = websocket
    online_users.add(user_id)
    
    # 广播在线用户列表更新
    await broadcast_online_users()

async def disconnect_user(user_id: int):
    """断开用户连接"""
    if user_id in user_connections:
        del user_connections[user_id]
    online_users.discard(user_id)
    
    # 广播在线用户列表更新
    await broadcast_online_users()

async def broadcast_online_users():
    """广播在线用户列表"""
    message = {
        "type": "online_users",
        "data": {
            "user_ids": list(online_users)
        }
    }
    
    for connection in user_connections.values():
        await connection.send_json(message)

async def handle_chat_websocket(websocket: WebSocket, room_id: int, db: Session):
    """处理聊天室WebSocket连接"""
    try:
        # 获取当前用户
        user = await get_current_user_ws(websocket, db)
        
        # 检查用户是否是聊天室成员
        member = db.query(RoomMember).filter(
            RoomMember.room_id == room_id,
            RoomMember.user_id == user.id
        ).first()
        
        if not member:
            await websocket.close(code=1008, reason="User not in room")
            return
        
        # 接受WebSocket连接
        await websocket.accept()
        
        # 连接到聊天室
        await connect_to_room(websocket, room_id, user.id)
        
        # 连接用户
        await connect_user(websocket, user.id)
        
        try:
            while True:
                # 接收消息
                data = await websocket.receive_text()
                message_data = json.loads(data)
                
                # 处理不同类型的消息
                if message_data.get("type") == "message":
                    # 创建消息记录
                    from ..models.message import Message
                    from ..schemas.message import MessageCreate
                    
                    message_create = MessageCreate(content=message_data["data"]["content"])
                    db_message = Message(
                        sender_id=user.id,
                        room_id=room_id,
                        content=message_create.content
                    )
                    db.add(db_message)
                    db.commit()
                    db.refresh(db_message)
                    
                    # 广播消息
                    message = {
                        "type": "message",
                        "data": {
                            "id": db_message.id,
                            "sender_id": db_message.sender_id,
                            "room_id": db_message.room_id,
                            "content": db_message.content,
                            "created_at": db_message.created_at.isoformat(),
                            "is_read": db_message.is_read,
                            "sender": {
                                "id": user.id,
                                "username": user.username,
                                "email": user.email
                            }
                        }
                    }
                    await broadcast_message(room_id, message)
                
                elif message_data.get("type") == "typing":
                    # 广播用户正在输入
                    message = {
                        "type": "typing",
                        "data": {
                            "user_id": user.id,
                            "is_typing": message_data["data"]["is_typing"]
                        }
                    }
                    await broadcast_message(room_id, message)
        
        except WebSocketDisconnect:
            # 断开连接
            await disconnect_from_room(websocket, room_id, user.id)
            await disconnect_user(user.id)
    
    except Exception as e:
        print(f"WebSocket error: {e}")
        try:
            await websocket.close(code=1011, reason="Internal server error")
        except:
            pass

async def handle_users_websocket(websocket: WebSocket, db: Session):
    """处理在线用户列表WebSocket连接"""
    try:
        # 获取当前用户
        user = await get_current_user_ws(websocket, db)
        
        # 接受WebSocket连接
        await websocket.accept()
        
        # 连接用户
        await connect_user(websocket, user.id)
        
        try:
            while True:
                # 保持连接活跃
                await websocket.receive_text()
        except WebSocketDisconnect:
            # 断开连接
            await disconnect_user(user.id)
    
    except Exception as e:
        print(f"WebSocket error: {e}")
        try:
            await websocket.close(code=1011, reason="Internal server error")
        except:
            pass