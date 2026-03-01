from fastapi import FastAPI, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import timedelta
from typing import List

from database import get_db, engine, Base
from models.user import User
from models.room import Room
from models.message import Message
from schemas.user import UserCreate, User as UserSchema, Token, UserLogin
from schemas.room import RoomCreate, Room as RoomSchema
from schemas.message import MessageCreate, Message as MessageSchema
from services.auth_service import (
    get_password_hash, authenticate_user, create_access_token, 
    verify_token, ACCESS_TOKEN_EXPIRE_MINUTES
)
from services.chat_service import (
    create_room, get_user_rooms, get_room, add_user_to_room,
    send_message, get_room_messages, get_room_members, is_user_in_room
)
from services.ws_service import manager

# 创建数据库表
Base.metadata.create_all(bind=engine)

# 初始化FastAPI应用
app = FastAPI()

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 在生产环境中应该设置具体的域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 依赖项：获取当前用户
async def get_current_user(token: str = Depends(lambda x: x.headers.get("Authorization").split(" ")[1] if x.headers.get("Authorization") else None), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not token:
        raise credentials_exception
    token_data = verify_token(token, credentials_exception)
    user = db.query(User).filter(User.id == token_data.user_id).first()
    if user is None:
        raise credentials_exception
    return user

# 用户注册
@app.post("/register", response_model=UserSchema)
def register(user: UserCreate, db: Session = Depends(get_db)):
    # 检查用户名是否已存在
    db_user = db.query(User).filter(User.username == user.username).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )
    # 检查邮箱是否已存在
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    # 创建新用户
    hashed_password = get_password_hash(user.password)
    db_user = User(
        username=user.username,
        email=user.email,
        password_hash=hashed_password
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# 用户登录
@app.post("/login", response_model=Token)
def login(user: UserLogin, db: Session = Depends(get_db)):
    user = authenticate_user(db, user.username, user.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

# 获取当前用户信息
@app.get("/users/me", response_model=UserSchema)
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

# 创建聊天室
@app.post("/rooms", response_model=RoomSchema)
def create_new_room(room: RoomCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_room = create_room(db, room, current_user.id)
    return db_room

# 获取用户的聊天室列表
@app.get("/rooms", response_model=List[RoomSchema])
def get_rooms(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rooms = get_user_rooms(db, current_user.id)
    return rooms

# 获取聊天室详情
@app.get("/rooms/{room_id}", response_model=RoomSchema)
def get_room_detail(room_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    room = get_room(db, room_id)
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found"
        )
    # 检查用户是否在聊天室中
    if not is_user_in_room(db, room_id, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this room"
        )
    # 获取聊天室成员
    room.members = get_room_members(db, room_id)
    return room

# 添加用户到聊天室
@app.post("/rooms/{room_id}/add/{user_id}")
def add_user(room_id: int, user_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # 检查聊天室是否存在
    room = get_room(db, room_id)
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found"
        )
    # 检查目标用户是否存在
    target_user = db.query(User).filter(User.id == user_id).first()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    # 添加用户到聊天室
    success = add_user_to_room(db, room_id, user_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already in the room"
        )
    return {"detail": "User added to room successfully"}

# 发送消息
@app.post("/messages", response_model=MessageSchema)
def send_new_message(message: MessageCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_message = send_message(db, message, current_user.id)
    if not db_message:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this room"
        )
    # 加载发送者信息
    db_message.sender = current_user
    return db_message

# 获取聊天室消息
@app.get("/rooms/{room_id}/messages", response_model=List[MessageSchema])
def get_messages(room_id: int, skip: int = 0, limit: int = 100, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # 检查用户是否在聊天室中
    if not is_user_in_room(db, room_id, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this room"
        )
    messages = get_room_messages(db, room_id, skip, limit)
    # 加载发送者信息
    for message in messages:
        message.sender = db.query(User).filter(User.id == message.sender_id).first()
    return messages

# WebSocket端点
@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: int):
    await manager.connect(websocket, user_id)
    try:
        # 广播用户上线
        online_users = manager.get_online_users()
        await manager.broadcast_to_room(
            json.dumps({"type": "online_users", "users": online_users}),
            0  # 全局房间
        )
        
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            if message_data["type"] == "join_room":
                room_id = message_data["room_id"]
                manager.add_user_to_room(user_id, room_id)
                
            elif message_data["type"] == "leave_room":
                room_id = message_data["room_id"]
                manager.remove_user_from_room(user_id, room_id)
                
            elif message_data["type"] == "message":
                room_id = message_data["room_id"]
                content = message_data["content"]
                
                # 保存消息到数据库
                db = next(get_db())
                message = MessageCreate(room_id=room_id, content=content)
                db_message = send_message(db, message, user_id)
                
                if db_message:
                    # 广播消息到房间
                    await manager.broadcast_to_room(
                        json.dumps({
                            "type": "message",
                            "id": db_message.id,
                            "sender_id": user_id,
                            "room_id": room_id,
                            "content": content,
                            "created_at": db_message.created_at.isoformat()
                        }),
                        room_id
                    )
    except WebSocketDisconnect:
        manager.disconnect(user_id)
        # 广播用户下线
        online_users = manager.get_online_users()
        await manager.broadcast_to_room(
            json.dumps({"type": "online_users", "users": online_users}),
            0  # 全局房间
        )

# 根路径
@app.get("/")
def read_root():
    return {"message": "Welcome to Chat App API"}