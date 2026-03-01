from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List, Optional
import os

from database import get_db, init_db
from models.user import User
from models.room import Room
from models.message import Message

from schemas.user import UserCreate, UserLogin, UserResponse, Token, UserUpdate
from schemas.room import RoomCreate, RoomUpdate, RoomResponse, RoomListResponse
from schemas.message import MessageCreate, MessageResponse

from services.auth_service import (
    create_user, authenticate_user, create_access_token,
    get_current_active_user, update_user_online_status,
    get_user_by_id, get_user_by_username, get_password_hash
)
from services.chat_service import (
    create_room, get_room_by_id, get_user_rooms, is_room_member,
    add_room_member, remove_room_member, create_message,
    get_room_messages, get_room_message_count, get_online_users,
    get_all_users, get_last_message, get_unread_message_count
)
from services.ws_service import ws_manager

# 创建FastAPI应用
app = FastAPI(
    title="Chat App API",
    description="类似微信的聊天应用API",
    version="1.0.0"
)

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==================== 认证相关接口 ====================

@app.post("/api/auth/register", response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    """用户注册"""
    return create_user(db, user)


@app.post("/api/auth/login", response_model=Token)
def login(user_login: UserLogin, db: Session = Depends(get_db)):
    """用户登录"""
    user = authenticate_user(db, user_login.username, user_login.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # 更新在线状态
    update_user_online_status(db, user.id, True)
    
    access_token = create_access_token(data={"sub": user.username})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user
    }


@app.post("/api/auth/logout")
def logout(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """用户登出"""
    update_user_online_status(db, current_user.id, False)
    return {"message": "登出成功"}


@app.get("/api/auth/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_active_user)):
    """获取当前用户信息"""
    return current_user


# ==================== 用户相关接口 ====================

@app.get("/api/users", response_model=List[UserResponse])
def get_users(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """获取所有用户列表"""
    return get_all_users(db, current_user.id)


@app.get("/api/users/online", response_model=List[UserResponse])
def get_online_users_list(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """获取在线用户列表"""
    return get_online_users(db)


# ==================== 聊天室相关接口 ====================

@app.post("/api/rooms", response_model=RoomResponse)
def create_new_room(
    room: RoomCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """创建聊天室"""
    return create_room(db, room, current_user.id)


@app.get("/api/rooms", response_model=List[RoomListResponse])
def get_my_rooms(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """获取我的聊天室列表"""
    rooms = get_user_rooms(db, current_user.id)
    result = []
    for room in rooms:
        last_msg = get_last_message(db, room.id)
        unread_count = get_unread_message_count(db, room.id, current_user.id)
        
        result.append(RoomListResponse(
            id=room.id,
            name=room.name,
            description=room.description,
            is_group=room.is_group,
            member_count=len(room.members),
            unread_count=unread_count,
            last_message=last_msg.content if last_msg else None,
            last_message_time=last_msg.created_at if last_msg else None
        ))
    return result


@app.get("/api/rooms/{room_id}", response_model=RoomResponse)
def get_room_detail(
    room_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """获取聊天室详情"""
    if not is_room_member(db, room_id, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="您不是该聊天室的成员"
        )
    
    room = get_room_by_id(db, room_id)
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="聊天室不存在"
        )
    return room


@app.post("/api/rooms/{room_id}/join")
def join_room(
    room_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """加入聊天室"""
    add_room_member(db, room_id, current_user.id)
    return {"message": "加入成功"}


@app.post("/api/rooms/{room_id}/leave")
def leave_room(
    room_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """离开聊天室"""
    remove_room_member(db, room_id, current_user.id)
    return {"message": "离开成功"}


# ==================== 消息相关接口 ====================

@app.get("/api/rooms/{room_id}/messages", response_model=List[MessageResponse])
def get_messages(
    room_id: int,
    page: int = 1,
    page_size: int = 50,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """获取聊天室消息"""
    if not is_room_member(db, room_id, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="您不是该聊天室的成员"
        )
    
    return get_room_messages(db, room_id, page, page_size)


@app.post("/api/rooms/{room_id}/messages", response_model=MessageResponse)
def send_message(
    room_id: int,
    message: MessageCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """发送消息"""
    message.room_id = room_id
    return create_message(db, message, current_user.id)


# ==================== WebSocket接口 ====================

@app.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str, db: Session = Depends(get_db)):
    """WebSocket连接端点"""
    from jose import jwt, JWTError
    from services.auth_service import SECRET_KEY, ALGORITHM
    
    # 验证token
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            await websocket.close(code=4001)
            return
    except JWTError:
        await websocket.close(code=4001)
        return
    
    user = get_user_by_username(db, username)
    if not user:
        await websocket.close(code=4001)
        return
    
    # 建立连接
    await ws_manager.connect(websocket, user.id)
    
    # 更新在线状态
    update_user_online_status(db, user.id, True)
    
    # 通知所有用户在线列表变化
    await ws_manager.notify_online_users_changed()
    
    try:
        while True:
            # 接收消息
            data = await websocket.receive_json()
            message_type = data.get("type")
            message_data = data.get("data", {})
            
            if message_type == "join_room":
                room_id = message_data.get("room_id")
                if room_id and is_room_member(db, room_id, user.id):
                    await ws_manager.join_room(user.id, room_id)
                    await ws_manager.send_personal_message(user.id, {
                        "type": "joined_room",
                        "data": {"room_id": room_id}
                    })
            
            elif message_type == "leave_room":
                room_id = message_data.get("room_id")
                if room_id:
                    await ws_manager.leave_room(user.id, room_id)
            
            elif message_type == "message":
                room_id = message_data.get("room_id")
                content = message_data.get("content")
                message_type_str = message_data.get("message_type", "text")
                
                if room_id and content and is_room_member(db, room_id, user.id):
                    # 保存消息到数据库
                    msg_create = MessageCreate(
                        content=content,
                        room_id=room_id,
                        message_type=message_type_str
                    )
                    new_message = create_message(db, msg_create, user.id)
                    
                    # 广播消息到房间
                    await ws_manager.broadcast_to_room(room_id, {
                        "type": "message",
                        "data": {
                            "id": new_message.id,
                            "content": new_message.content,
                            "sender_id": new_message.sender_id,
                            "sender_name": user.username,
                            "room_id": new_message.room_id,
                            "message_type": new_message.message_type,
                            "created_at": new_message.created_at.isoformat()
                        }
                    })
            
            elif message_type == "typing":
                room_id = message_data.get("room_id")
                if room_id and is_room_member(db, room_id, user.id):
                    await ws_manager.broadcast_to_room(room_id, {
                        "type": "typing",
                        "data": {
                            "user_id": user.id,
                            "username": user.username,
                            "room_id": room_id
                        }
                    }, exclude_user=user.id)
            
            elif message_type == "ping":
                await ws_manager.send_personal_message(user.id, {
                    "type": "pong",
                    "data": {}
                })
    
    except WebSocketDisconnect:
        # 断开连接
        ws_manager.disconnect(user.id)
        update_user_online_status(db, user.id, False)
        await ws_manager.notify_online_users_changed()


# ==================== 静态文件服务 ====================

# 检查前端构建目录是否存在
frontend_build_path = os.path.join(os.path.dirname(__file__), "frontend", "build")
if os.path.exists(frontend_build_path):
    app.mount("/static", StaticFiles(directory=os.path.join(frontend_build_path, "static")), name="static")
    
    @app.get("/")
    async def serve_react_app():
        return FileResponse(os.path.join(frontend_build_path, "index.html"))
    
    @app.get("/{path:path}")
    async def serve_react_routes(path: str):
        file_path = os.path.join(frontend_build_path, path)
        if os.path.exists(file_path):
            return FileResponse(file_path)
        return FileResponse(os.path.join(frontend_build_path, "index.html"))


# ==================== 启动事件 ====================

@app.on_event("startup")
async def startup_event():
    """应用启动时初始化数据库"""
    init_db()
    print("数据库初始化完成")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
