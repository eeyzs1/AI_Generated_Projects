from fastapi import FastAPI, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from typing import List

from .database import get_db, engine, Base
from .models import user, room, message
from .schemas.user import UserCreate, UserResponse, Token, UserLogin
from .schemas.room import RoomCreate, RoomResponse, RoomInvite
from .schemas.message import MessageCreate, MessageResponse
from .services.auth_service import (
    register_user,
    authenticate_user,
    create_access_token,
    get_current_active_user,
    ACCESS_TOKEN_EXPIRE_MINUTES
)
from .services.chat_service import (
    create_room,
    get_user_rooms,
    get_room,
    join_room,
    leave_room,
    invite_user_to_room,
    send_message,
    get_room_messages
)
from .services.ws_service import handle_chat_websocket, handle_users_websocket
from datetime import timedelta

# 创建数据库表
Base.metadata.create_all(bind=engine)

# 创建FastAPI应用
app = FastAPI(title="Chat App API", description="A simple chat application API")

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 在生产环境中应该指定允许的源
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 认证相关路由
@app.post("/api/auth/register", response_model=UserResponse)
def register(user_create: UserCreate, db: Session = Depends(get_db)):
    """注册新用户"""
    return register_user(db, user_create)

@app.post("/api/auth/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """用户登录"""
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/api/auth/me", response_model=UserResponse)
async def get_me(current_user = Depends(get_current_active_user)):
    """获取当前用户信息"""
    return current_user

# 聊天室相关路由
@app.post("/api/rooms", response_model=RoomResponse)
async def create_new_room(
    room_create: RoomCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_active_user)
):
    """创建新聊天室"""
    room = create_room(db, room_create, current_user.id)
    return room

@app.get("/api/rooms", response_model=List[RoomResponse])
async def get_my_rooms(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_active_user)
):
    """获取用户加入的聊天室列表"""
    return get_user_rooms(db, current_user.id)

@app.get("/api/rooms/{room_id}", response_model=RoomResponse)
async def get_room_details(
    room_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_active_user)
):
    """获取聊天室详情"""
    return get_room(db, room_id)

@app.post("/api/rooms/{room_id}/join")
async def join_room_endpoint(
    room_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_active_user)
):
    """加入聊天室"""
    join_room(db, room_id, current_user.id)
    return {"message": "Successfully joined room"}

@app.delete("/api/rooms/{room_id}/leave")
async def leave_room_endpoint(
    room_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_active_user)
):
    """离开聊天室"""
    leave_room(db, room_id, current_user.id)
    return {"message": "Successfully left room"}

@app.post("/api/rooms/{room_id}/invite")
async def invite_user(
    room_id: int,
    invite: RoomInvite,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_active_user)
):
    """邀请用户加入聊天室"""
    invite_user_to_room(db, room_id, current_user.id, invite.user_id)
    return {"message": "Successfully invited user"}

# 消息相关路由
@app.post("/api/rooms/{room_id}/messages", response_model=MessageResponse)
async def send_new_message(
    room_id: int,
    message_create: MessageCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_active_user)
):
    """发送消息"""
    return send_message(db, room_id, current_user.id, message_create)

@app.get("/api/rooms/{room_id}/messages", response_model=List[MessageResponse])
async def get_messages(
    room_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_active_user)
):
    """获取聊天记录"""
    return get_room_messages(db, room_id, current_user.id, skip, limit)

# WebSocket路由
@app.websocket("/ws/chat/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: int, db: Session = Depends(get_db)):
    """聊天室WebSocket端点"""
    await handle_chat_websocket(websocket, room_id, db)

@app.websocket("/ws/users")
async def users_websocket_endpoint(websocket: WebSocket, db: Session = Depends(get_db)):
    """在线用户列表WebSocket端点"""
    await handle_users_websocket(websocket, db)

# 根路由
@app.get("/")
def read_root():
    return {"message": "Welcome to Chat App API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)