from fastapi import FastAPI, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List

from database import get_db, init_db
from models import User
from schemas import (
    UserCreate, UserLogin, UserResponse, Token,
    RoomCreate, RoomResponse, RoomDetail, AddMember,
    MessageCreate, MessageResponse, WSMessage
)
from services import (
    create_user, authenticate_user, create_access_token,
    verify_token, get_user_by_id, get_all_users,
    create_room, get_user_rooms, get_room_detail, add_member_to_room,
    create_message, get_room_messages, update_user_online_status,
    manager
)

# 初始化FastAPI应用
app = FastAPI(title="Chat App", version="1.0.0")

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OAuth2密码bearer
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login")


# 依赖：获取当前用户
async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """获取当前登录用户"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    token_data = verify_token(token)
    if token_data is None:
        raise credentials_exception
    user = get_user_by_username(db, username=token_data.username)
    if user is None:
        raise credentials_exception
    return user


# 启动事件
@app.on_event("startup")
async def startup_event():
    """应用启动时初始化数据库"""
    init_db()


# 健康检查
@app.get("/")
async def root():
    return {"message": "Chat App API is running"}


# ============= 认证相关接口 =============
@app.post("/api/auth/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user: UserCreate, db: Session = Depends(get_db)):
    """用户注册"""
    from services import get_user_by_username, get_user_by_email

    # 检查用户名是否已存在
    if get_user_by_username(db, user.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )
    # 检查邮箱是否已存在
    if get_user_by_email(db, user.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # 创建用户
    db_user = create_user(db, user)
    return db_user


@app.post("/api/auth/login", response_model=Token)
async def login(user_login: UserLogin, db: Session = Depends(get_db)):
    """用户登录"""
    user = authenticate_user(db, user_login.username, user_login.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 创建访问令牌
    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}


@app.get("/api/auth/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """获取当前用户信息"""
    return current_user


# ============= 用户相关接口 =============
@app.get("/api/users", response_model=List[UserResponse])
async def get_users(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取所有用户列表"""
    users = get_all_users(db)
    return users


# ============= 聊天室相关接口 =============
@app.post("/api/rooms", response_model=RoomResponse, status_code=status.HTTP_201_CREATED)
async def create_chat_room(
    room: RoomCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """创建聊天室"""
    db_room = create_room(db, room, current_user.id)
    return db_room


@app.get("/api/rooms", response_model=List[RoomResponse])
async def get_chat_rooms(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取当前用户所在的所有聊天室"""
    rooms = get_user_rooms(db, current_user.id)
    return rooms


@app.get("/api/rooms/{room_id}", response_model=RoomDetail)
async def get_chat_room(
    room_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取聊天室详情"""
    room = get_room_detail(db, room_id)
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found"
        )
    return room


@app.post("/api/rooms/members", status_code=status.HTTP_200_OK)
async def add_room_member(
    add_member: AddMember,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """添加成员到聊天室"""
    from services import get_room, is_room_member

    # 检查聊天室是否存在
    room = get_room(db, add_member.room_id)
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found"
        )

    # 检查当前用户是否为房间创建者
    if room.creator_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only room creator can add members"
        )

    # 检查要添加的用户是否存在
    target_user = get_user_by_id(db, add_member.user_id)
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    # 检查用户是否已在房间中
    if is_room_member(db, add_member.room_id, add_member.user_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already in room"
        )

    # 添加成员
    success = add_member_to_room(db, add_member)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to add member"
        )

    # 获取房间成员列表
    room_detail = get_room_detail(db, add_member.room_id)
    await manager.broadcast_to_room(
        {"type": "user_join", "data": {"room_id": add_member.room_id, "user_id": add_member.user_id}},
        room_detail.members
    )

    return {"message": "Member added successfully"}


# ============= 消息相关接口 =============
@app.get("/api/rooms/{room_id}/messages", response_model=List[MessageResponse])
async def get_messages(
    room_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取聊天室消息"""
    from services import is_room_member

    # 检查用户是否为房间成员
    if not is_room_member(db, room_id, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this room"
        )

    messages = get_room_messages(db, room_id)
    return messages


# ============= WebSocket接口 =============
@app.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str, db: Session = Depends(get_db)):
    """WebSocket连接端点"""
    # 验证token
    token_data = verify_token(token)
    if token_data is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user = get_user_by_username(db, username=token_data.username)
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # 连接用户
    await manager.connect(websocket, user.id)

    # 更新用户在线状态
    update_user_online_status(db, user.id, 1)

    # 广播在线用户列表
    online_users = manager.get_online_users()
    await manager.broadcast_online_users(online_users)

    try:
        while True:
            # 接收消息
            data = await websocket.receive_json()

            if data.get("type") == "message":
                # 发送消息
                message_create = MessageCreate(
                    room_id=data["room_id"],
                    content=data["content"]
                )
                db_message = create_message(db, message_create, user.id)

                if db_message:
                    # 获取房间成员列表
                    from services import get_room_detail
                    room_detail = get_room_detail(db, data["room_id"])

                    # 广播消息
                    message_response = {
                        "type": "message",
                        "data": {
                            "id": db_message.id,
                            "room_id": db_message.room_id,
                            "sender_id": db_message.sender_id,
                            "sender_username": user.username,
                            "content": db_message.content,
                            "created_at": db_message.created_at.isoformat()
                        }
                    }
                    await manager.broadcast_to_room(message_response, room_detail.members)

    except WebSocketDisconnect:
        # 断开连接
        manager.disconnect(websocket, user.id)
        update_user_online_status(db, user.id, 0)

        # 广播在线用户列表
        online_users = manager.get_online_users()
        await manager.broadcast_online_users(online_users)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
