# 基于 FastAPI + React 的简易微信聊天应用开发

### 需求理解

你需要一个基于FastAPI+React的简易微信聊天应用，包含用户注册登录、聊天室管理、实时消息收发、在线用户列表功能，要求代码按指定目录结构组织，支持MySQL存储和Docker容器化部署，且前后端集成在同一项目中。

### 项目完整代码实现

以下是按指定目录结构编写的完整代码，所有文件内容逐一列出：

---

#### 1. 项目依赖准备

先创建`requirements.txt`（chat_app/下），用于Python依赖管理：

```Plain Text

fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
asyncmy==0.2.8  # 异步MySQL驱动
passlib[bcrypt]==1.7.4
python-jose[cryptography]==3.3.0
python-multipart==0.0.6
pydantic==2.4.2
typing-extensions==4.8.0
```

#### 2. [database.py](database.py)（chat_app/下）

```Python

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

# MySQL数据库配置（请根据实际环境修改）
SQLALCHEMY_DATABASE_URL = "mysql+asyncmy://root:password@localhost:3306/chat_app"

# 异步引擎配置
async_engine = create_async_engine(
    SQLALCHEMY_DATABASE_URL,
    echo=True,
    pool_pre_ping=True,
)
AsyncSessionLocal = sessionmaker(
    async_engine, class_=AsyncSession, expire_on_commit=False
)

# 同步引擎（可选，用于初始化数据库）
sync_engine = create_engine(
    SQLALCHEMY_DATABASE_URL.replace("+asyncmy", ""),
    echo=True,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=sync_engine)

# ORM基类
Base = declarative_base()

# 获取异步数据库会话
async def get_db():
    db = AsyncSessionLocal()
    try:
        yield db
    finally:
        await db.close()

# 初始化数据库表
async def init_db():
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
```

#### 3. models/[user.py](user.py)（chat_app/models/下）

```Python

from sqlalchemy import Column, Integer, String, DateTime, Boolean
from sqlalchemy.sql import func
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
```

#### 4. models/[room.py](room.py)（chat_app/models/下）

```Python

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Table
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base

# 用户-房间多对多关联表
room_members = Table(
    "room_members",
    Base.metadata,
    Column("room_id", Integer, ForeignKey("rooms.id"), primary_key=True),
    Column("user_id", Integer, ForeignKey("users.id"), primary_key=True),
)

class Room(Base):
    __tablename__ = "rooms"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    creator_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # 关系映射
    creator = relationship("User", back_populates="created_rooms")
    members = relationship("User", secondary=room_members, back_populates="joined_rooms")
    messages = relationship("Message", back_populates="room", cascade="all, delete-orphan")

# 给User模型补充反向关系
from models.user import User
User.created_rooms = relationship("Room", back_populates="creator", foreign_keys=[Room.creator_id])
User.joined_rooms = relationship("Room", secondary=room_members, back_populates="members")
```

#### 5. models/[message.py](message.py)（chat_app/models/下）

```Python

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    room_id = Column(Integer, ForeignKey("rooms.id"), nullable=False)
    content = Column(String(500), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # 关系映射
    sender = relationship("User")
    room = relationship("Room", back_populates="messages")
```

#### 6. schemas/[user.py](user.py)（chat_app/schemas/下）

```Python

from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional

# 基础用户模型
class UserBase(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr

# 用户注册请求模型
class UserCreate(UserBase):
    password: str = Field(min_length=6, max_length=100)

# 用户登录请求模型
class UserLogin(BaseModel):
    username: str
    password: str

# 用户响应模型
class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
```

#### 7. schemas/[room.py](room.py)（chat_app/schemas/下）

```Python

from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional
from schemas.user import UserResponse

# 房间创建请求模型
class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)

# 房间成员添加请求模型
class RoomAddMember(BaseModel):
    room_id: int
    user_id: int

# 房间响应模型
class RoomResponse(BaseModel):
    id: int
    name: str
    creator_id: int
    created_at: datetime
    members: Optional[List[UserResponse]] = []

    class Config:
        from_attributes = True
```

#### 8. schemas/[message.py](message.py)（chat_app/schemas/下）

```Python

from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from schemas.user import UserResponse

# 消息发送请求模型
class MessageCreate(BaseModel):
    room_id: int
    content: str = Field(min_length=1, max_length=500)

# 消息响应模型
class MessageResponse(BaseModel):
    id: int
    sender_id: int
    room_id: int
    content: str
    created_at: datetime
    sender: Optional[UserResponse] = None

    class Config:
        from_attributes = True
```

#### 9. services/[auth_service.py](auth_service.py)（chat_app/services/下）

```Python

from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from fastapi import HTTPException, status, Depends
from database import get_db
from models.user import User
from schemas.user import UserCreate, UserLogin

# 密码加密配置
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT配置（请在生产环境使用环境变量）
SECRET_KEY = "your-secret-key-keep-it-safe-1234567890"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# 验证密码
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

# 生成密码哈希
def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

# 创建访问令牌
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# 用户注册
async def register_user(user_data: UserCreate, db: AsyncSession) -> User:
    # 检查用户名是否已存在
    result = await db.execute(select(User).where(User.username == user_data.username))
    if result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户名已存在"
        )
    # 检查邮箱是否已存在
    result = await db.execute(select(User).where(User.email == user_data.email))
    if result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="邮箱已存在"
        )
    # 创建新用户
    hashed_password = get_password_hash(user_data.password)
    db_user = User(
        username=user_data.username,
        email=user_data.email,
        hashed_password=hashed_password
    )
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    return db_user

# 用户登录
async def login_user(user_data: UserLogin, db: AsyncSession) -> str:
    # 查询用户
    result = await db.execute(select(User).where(User.username == user_data.username))
    user = result.scalars().first()
    if not user or not verify_password(user_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    # 生成令牌
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    return access_token

# 获取当前登录用户
async def get_current_user(
    token: str = Depends(lambda: None),  # 实际由FastAPI的Depends注入
    db: AsyncSession = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无法验证凭据",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    # 查询用户
    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalars().first()
    if user is None:
        raise credentials_exception
    return user
```

#### 10. services/[chat_service.py](chat_service.py)（chat_app/services/下）

```Python

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status
from models.room import Room, room_members
from models.message import Message
from models.user import User
from schemas.room import RoomCreate, RoomAddMember
from schemas.message import MessageCreate

# 创建聊天室
async def create_room(room_data: RoomCreate, user_id: int, db: AsyncSession) -> Room:
    # 创建房间
    db_room = Room(
        name=room_data.name,
        creator_id=user_id
    )
    db.add(db_room)
    await db.commit()
    await db.refresh(db_room)
    # 将创建者加入房间
    await add_room_member(RoomAddMember(room_id=db_room.id, user_id=user_id), db)
    return db_room

# 添加房间成员
async def add_room_member(member_data: RoomAddMember, db: AsyncSession) -> Room:
    # 检查房间是否存在
    result = await db.execute(select(Room).where(Room.id == member_data.room_id))
    room = result.scalars().first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="房间不存在"
        )
    # 检查用户是否存在
    result = await db.execute(select(User).where(User.id == member_data.user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    # 检查用户是否已在房间
    result = await db.execute(
        select(room_members).where(
            room_members.c.room_id == member_data.room_id,
            room_members.c.user_id == member_data.user_id
        )
    )
    if result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户已在房间中"
        )
    # 添加成员
    await db.execute(
        room_members.insert().values(
            room_id=member_data.room_id,
            user_id=member_data.user_id
        )
    )
    await db.commit()
    # 刷新房间数据
    await db.refresh(room)
    return room

# 获取用户加入的所有房间
async def get_user_rooms(user_id: int, db: AsyncSession) -> list[Room]:
    result = await db.execute(
        select(Room)
        .join(room_members)
        .where(room_members.c.user_id == user_id)
        .options(selectinload(Room.members))
    )
    return result.scalars().all()

# 发送消息
async def send_message(message_data: MessageCreate, user_id: int, db: AsyncSession) -> Message:
    # 检查房间是否存在
    result = await db.execute(select(Room).where(Room.id == message_data.room_id))
    room = result.scalars().first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="房间不存在"
        )
    # 检查用户是否在房间中
    result = await db.execute(
        select(room_members).where(
            room_members.c.room_id == message_data.room_id,
            room_members.c.user_id == user_id
        )
    )
    if not result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="你不是该房间成员"
        )
    # 创建消息
    db_message = Message(
        sender_id=user_id,
        room_id=message_data.room_id,
        content=message_data.content
    )
    db.add(db_message)
    await db.commit()
    await db.refresh(db_message)
    # 关联发送者信息
    await db.refresh(db_message, ["sender"])
    return db_message

# 获取房间消息记录
async def get_room_messages(room_id: int, user_id: int, db: AsyncSession) -> list[Message]:
    # 检查用户是否在房间中
    result = await db.execute(
        select(room_members).where(
            room_members.c.room_id == room_id,
            room_members.c.user_id == user_id
        )
    )
    if not result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="你不是该房间成员"
        )
    # 查询消息
    result = await db.execute(
        select(Message)
        .where(Message.room_id == room_id)
        .order_by(Message.created_at)
        .options(selectinload(Message.sender))
    )
    return result.scalars().all()
```

#### 11. services/[ws_service.py](ws_service.py)（chat_app/services/下）

```Python

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
```

#### 12. [main.py](main.py)（chat_app/下）

```Python

from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from jose import JWTError, jwt
from typing import List

from database import get_db, init_db
from schemas.user import UserCreate, UserLogin, UserResponse
from schemas.room import RoomCreate, RoomResponse, RoomAddMember
from schemas.message import MessageCreate, MessageResponse
from services.auth_service import register_user, login_user, get_current_user, SECRET_KEY, ALGORITHM
from services.chat_service import create_room, add_room_member, get_user_rooms, send_message, get_room_messages
from services.ws_service import user_online, user_offline, handle_websocket_message
from models.user import User

# 初始化FastAPI应用
app = FastAPI(title="简易聊天应用", version="1.0")

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境请指定具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 挂载前端静态文件
app.mount("/static", StaticFiles(directory="frontend/build/static"), name="static")

# 初始化数据库（启动时执行）
@app.on_event("startup")
async def startup_event():
    await init_db()

# 前端页面路由
@app.get("/")
async def read_root():
    return FileResponse("frontend/build/index.html")

# ------------------------------
# 认证接口
# ------------------------------
@app.post("/api/register", response_model=UserResponse)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    return await register_user(user_data, db)

@app.post("/api/login")
async def login(
    user_data: UserLogin,
    db: AsyncSession = Depends(get_db)
):
    token = await login_user(user_data, db)
    return {"access_token": token, "token_type": "bearer"}

@app.get("/api/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user)
):
    return current_user

# ------------------------------
# 聊天室接口
# ------------------------------
@app.post("/api/rooms", response_model=RoomResponse)
async def create_chat_room(
    room_data: RoomCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    return await create_room(room_data, current_user.id, db)

@app.post("/api/rooms/add_member")
async def add_member_to_room(
    member_data: RoomAddMember,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 仅房间创建者可添加成员
    result = await db.execute(
        select(Room).where(Room.id == member_data.room_id)
    )
    room = result.scalars().first()
    if room.creator_id != current_user.id:
        raise HTTPException(status_code=403, detail="仅创建者可添加成员")
    return await add_room_member(member_data, db)

@app.get("/api/rooms", response_model=List[RoomResponse])
async def get_my_rooms(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    return await get_user_rooms(current_user.id, db)

# ------------------------------
# 消息接口
# ------------------------------
@app.post("/api/messages", response_model=MessageResponse)
async def send_chat_message(
    message_data: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    return await send_message(message_data, current_user.id, db)

@app.get("/api/rooms/{room_id}/messages", response_model=List[MessageResponse])
async def get_messages(
    room_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    return await get_room_messages(room_id, current_user.id, db)

# ------------------------------
# WebSocket接口
# ------------------------------
@app.websocket("/api/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = None,
    db: AsyncSession = Depends(get_db)
):
    await websocket.accept()
    
    # 验证token
    if not token:
        await websocket.close(code=1008)
        return
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload.get("sub"))
        # 验证用户存在
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalars().first()
        if not user:
            await websocket.close(code=1008)
            return
    except (JWTError, ValueError):
        await websocket.close(code=1008)
        return
    
    # 用户上线
    await user_online(user_id, websocket)
    
    try:
        # 持续接收消息
        while True:
            data = await websocket.receive_json()
            await handle_websocket_message(websocket, data, user_id)
    except WebSocketDisconnect:
        # 用户下线
        await user_offline(user_id)

# 启动命令：uvicorn main:app --reload --host 0.0.0.0 --port 8000
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
```

#### 13. frontend/package.json（chat_app/frontend/下）

```JSON

{
  "name": "chat-frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@types/react": "^18.2.37",
    "@types/react-dom": "^18.2.15",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.18.0",
    "react-scripts": "5.0.1",
    "typescript": "^4.9.5",
    "web-vitals": "^2.1.4"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "proxy": "http://localhost:8000"
}
```

#### 14. frontend/public/index.html（chat_app/frontend/public/下）

```HTML

<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <title>简易聊天应用</title>
    <style>
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        line-height: 1.5;
        color: #333;
        background-color: #f5f5f5;
      }
      .container {
        max-width: 1200px;
        margin: 0 auto;
        padding: 20px;
      }
      .card {
        background: white;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        padding: 20px;
        margin-bottom: 20px;
      }
      input, button, textarea {
        width: 100%;
        padding: 10px;
        margin-bottom: 10px;
        border: 1px solid #ddd;
        border-radius: 4px;
        font-size: 16px;
      }
      button {
        background-color: #007bff;
        color: white;
        border: none;
        cursor: pointer;
      }
      button:hover {
        background-color: #0056b3;
      }
      .chat-container {
        display: flex;
        gap: 20px;
        height: 80vh;
      }
      .user-list {
        width: 250px;
        background: white;
        border-radius: 8px;
        padding: 10px;
        overflow-y: auto;
      }
      .chat-room {
        flex: 1;
        display: flex;
        flex-direction: column;
        background: white;
        border-radius: 8px;
        padding: 10px;
      }
      .messages {
        flex: 1;
        overflow-y: auto;
        padding: 10px;
        margin-bottom: 10px;
      }
      .message {
        margin-bottom: 10px;
        padding: 8px 12px;
        border-radius: 16px;
        max-width: 70%;
      }
      .message.sent {
        background-color: #007bff;
        color: white;
        margin-left: auto;
      }
      .message.received {
        background-color: #e9ecef;
        color: #333;
      }
      .message-input {
        display: flex;
        gap: 10px;
      }
      .message-input input {
        flex: 1;
        margin-bottom: 0;
      }
      .message-input button {
        width: 100px;
        margin-bottom: 0;
      }
      .room-list {
        margin-bottom: 20px;
      }
      .room-item {
        padding: 10px;
        background: #e9ecef;
        border-radius: 4px;
        margin-bottom: 5px;
        cursor: pointer;
      }
      .room-item:hover {
        background: #dee2e6;
      }
    </style>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
```

#### 15. frontend/src/App.tsx（chat_app/frontend/src/下）

```TypeScript

import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';

interface User {
  id: number;
  username: string;
  email: string;
}

const App: React.FC = () => {
  const [token, setToken] = useState<string | null>(localStorage.getItem('token'));
  const [currentUser, setCurrentUser] = useState<User | null>(null);

  // 加载当前用户信息
  useEffect(() => {
    if (token) {
      fetch('/api/me', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })
      .then(res => {
        if (res.ok) return res.json();
        throw new Error('认证失败');
      })
      .then(data => setCurrentUser(data))
      .catch(() => {
        localStorage.removeItem('token');
        setToken(null);
      });
    }
  }, [token]);

  // 处理登录
  const handleLogin = (newToken: string) => {
    localStorage.setItem('token', newToken);
    setToken(newToken);
  };

  // 处理登出
  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken(null);
    setCurrentUser(null);
  };

  return (
    <Router>
      <div className="container">
        <h1>简易聊天应用</h1>
        {currentUser && (
          <div style={{ marginBottom: '20px', display: 'flex', justifyContent: 'space-between' }}>
            <p>当前登录：{currentUser.username}</p>
            <button onClick={handleLogout} style={{ width: '100px' }}>登出</button>
          </div>
        )}
        <Routes>
          <Route path="/login" element={token ? <Navigate to="/" /> : <Login onLogin={handleLogin} />} />
          <Route path="/register" element={token ? <Navigate to="/" /> : <Register />} />
          <Route path="/" element={token ? <ChatRoom token={token} user={currentUser!} /> : <Navigate to="/login" />} />
        </Routes>
      </div>
    </Router>
  );
};

export default App;
```

#### 16. frontend/src/Login.tsx（chat_app/frontend/src/下）

```TypeScript

import React, { useState } from 'react';
import { Link } from 'react-router-dom';

interface LoginProps {
  onLogin: (token: string) => void;
}

const Login: React.FC<LoginProps> = ({ onLogin }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('/api/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username, password })
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || '登录失败');
      
      onLogin(data.access_token);
    } catch (err) {
      setError(err instanceof Error ? err.message : '登录失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card" style={{ maxWidth: '400px', margin: '0 auto' }}>
      <h2>登录</h2>
      {error && <div style={{ color: 'red', marginBottom: '10px' }}>{error}</div>}
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="用户名"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          required
          disabled={loading}
        />
        <input
          type="password"
          placeholder="密码"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          disabled={loading}
        />
        <button type="submit" disabled={loading}>
          {loading ? '登录中...' : '登录'}
        </button>
      </form>
      <p style={{ marginTop: '10px', textAlign: 'center' }}>
        还没有账号？<Link to="/register">立即注册</Link>
      </p>
    </div>
  );
};

export default Login;
```

#### 17. frontend/src/Register.tsx（chat_app/frontend/src/下）

```TypeScript

import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

const Register: React.FC = () => {
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('/api/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username, email, password })
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || '注册失败');
      
      // 注册成功，跳转到登录页
      navigate('/login');
    } catch (err) {
      setError(err instanceof Error ? err.message : '注册失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card" style={{ maxWidth: '400px', margin: '0 auto' }}>
      <h2>注册</h2>
      {error && <div style={{ color: 'red', marginBottom: '10px' }}>{error}</div>}
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="用户名"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          required
          disabled={loading}
        />
        <input
          type="email"
          placeholder="邮箱"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          disabled={loading}
        />
        <input
          type="password"
          placeholder="密码（至少6位）"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          minLength={6}
          disabled={loading}
        />
        <button type="submit" disabled={loading}>
          {loading ? '注册中...' : '注册'}
        </button>
      </form>
      <p style={{ marginTop: '10px', textAlign: 'center' }}>
        已有账号？<Link to="/login">立即登录</Link>
      </p>
    </div>
  );
};

export default Register;
```

#### 18. frontend/src/UserList.tsx（chat_app/frontend/src/下）

```TypeScript

import React from 'react';

interface UserListProps {
  onlineUserIds: number[];
  currentUserId: number;
  users: { [key: number]: { id: number; username: string } };
}

const UserList: React.FC<UserListProps> = ({ onlineUserIds, currentUserId, users }) => {
  return (
    <div className="user-list">
      <h3>在线用户</h3>
      <hr />
      {onlineUserIds.length === 0 ? (
        <p>暂无在线用户</p>
      ) : (
        onlineUserIds.map(userId => (
          <div key={userId} style={{ padding: '8px', margin: '5px 0', borderRadius: '4px', background: userId === currentUserId ? '#e3f2fd' : '#f8f9fa' }}>
            {users[userId]?.username || `用户${userId}`}
            {userId === currentUserId && <span style={{ color: '#007bff', fontSize: '12px' }}> (我)</span>}
          </div>
        ))
      )}
    </div>
  );
};

export default UserList;
```

#### 19. frontend/src/ChatRoom.tsx（chat_app/frontend/src/下）

```TypeScript

import React, { useState, useEffect, useRef } from 'react';
import UserList from './UserList';

interface User {
  id: number;
  username: string;
  email: string;
}

interface Room {
  id: number;
  name: string;
  creator_id: number;
  members: User[];
}

interface Message {
  id: number;
  sender_id: number;
  room_id: number;
  content: string;
  created_at: string;
  sender: User;
}

interface ChatRoomProps {
  token: string;
  user: User;
}

const ChatRoom: React.FC<ChatRoomProps> = ({ token, user }) => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [currentRoom, setCurrentRoom] = useState<Room | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [onlineUserIds, setOnlineUserIds] = useState<number[]>([]);
  const [roomName, setRoomName] = useState('');
  const wsRef = useRef<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // 获取用户房间列表
  useEffect(() => {
    const fetchRooms = async () => {
      try {
        const res = await fetch('/api/rooms', {
          headers: {
            'Authorization': `Bearer ${token}`
          }
        });
        const data = await res.json();
        if (res.ok) {
          setRooms(data);
          // 默认选中第一个房间
          if (data.length > 0) {
            setCurrentRoom(data[0]);
          }
        }
      } catch (err) {
        console.error('获取房间失败:', err);
      }
    };

    fetchRooms();
  }, [token]);

  // 连接WebSocket
  useEffect(() => {
    // 创建WebSocket连接
    const ws = new WebSocket(`ws://${window.location.host}/api/ws?token=${token}`);
    wsRef.current = ws;

    // 连接成功
    ws.onopen = () => {
      console.log('WebSocket连接成功');
      // 如果有当前房间，加入房间
      if (currentRoom) {
        ws.send(JSON.stringify({
          type: 'join_room',
          room_id: currentRoom.id
        }));
        fetchRoomMessages(currentRoom.id);
      }
    };

    // 接收消息
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      switch (data.type) {
        case 'online_users':
          setOnlineUserIds(data.data);
          break;
        case 'new_message':
          const msg = data.data;
          setMessages(prev => [
            ...prev,
            {
              ...msg,
              id: Date.now(),
              sender: { id: msg.sender_id, username: `用户${msg.sender_id}`, email: '' }
            }
          ]);
          break;
      }
    };

    // 连接关闭
    ws.onclose = () => {
      console.log('WebSocket连接关闭，5秒后重连');
      setTimeout(() => {
        wsRef.current = null;
        // 重新触发effect
        setOnlineUserIds(prev => [...prev]);
      }, 5000);
    };

    // 清理函数
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [token, currentRoom?.id]);

  // 滚动到消息底部
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // 获取房间消息
  const fetchRoomMessages = async (roomId: number) => {
    try {
      const res = await fetch(`/api/rooms/${roomId}/messages`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      const data = await res.json();
      if (res.ok) {
        setMessages(data);
      }
    } catch (err) {
      console.error('获取消息失败:', err);
    }
  };

  // 切换房间
  const handleRoomChange = (room: Room) => {
    // 离开当前房间
    if (currentRoom && wsRef.current) {
      wsRef.current.send(JSON.stringify({
        type: 'leave_room',
        room_id: currentRoom.id
      }));
    }
    // 加入新房间
    setCurrentRoom(room);
    if (wsRef.current) {
      wsRef.current.send(JSON.stringify({
        type: 'join_room',
        room_id: room.id
      }));
    }
    // 获取新房间消息
    fetchRoomMessages(room.id);
  };

  // 发送消息
  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !currentRoom || !wsRef.current) return;

    // 发送消息到WebSocket
    const messageData = {
      type: 'send_message',
      room_id: currentRoom.id,
      content: newMessage,
      created_at: new Date().toISOString()
    };
    wsRef.current.send(JSON.stringify(messageData));

    // 同时调用API保存消息
    try {
      await fetch('/api/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          room_id: currentRoom.id,
          content: newMessage
        })
      });
    } catch (err) {
      console.error('保存消息失败:', err);
    }

    // 清空输入框
    setNewMessage('');
  };

  // 创建新房间
  const handleCreateRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!roomName.trim()) return;

    try {
      const res = await fetch('/api/rooms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name: roomName })
      });
      const data = await res.json();
      if (res.ok) {
        setRooms(prev => [...prev, data]);
        setRoomName('');
      }
    } catch (err) {
      console.error('创建房间失败:', err);
    }
  };

  // 构建用户信息映射
  const userMap: { [key: number]: User } = {};
  rooms.forEach(room => {
    room.members.forEach(member => {
      userMap[member.id] = member;
    });
  });
  userMap[user.id] = user;

  return (
    <div>
      {/* 创建房间表单 */}
      <div className="card">
        <h3>创建新聊天室</h3>
        <form onSubmit={handleCreateRoom}>
          <input
            type="text"
            placeholder="房间名称"
            value={roomName}
            onChange={(e) => setRoomName(e.target.value)}
            required
          />
          <button type="submit">创建房间</button>
        </form>
      </div>

      {/* 房间列表和聊天区域 */}
      <div className="chat-container">
        {/* 房间列表 */}
        <div className="user-list">
          <h3>我的聊天室</h3>
          <hr />
          {rooms.length === 0 ? (
            <p>暂无聊天室，创建一个吧！</p>
          ) : (
            rooms.map(room => (
              <div
                key={room.id}
                className="room-item"
                style={{ background: currentRoom?.id === room.id ? '#007bff' : '', color: currentRoom?.id === room.id ? 'white' : '' }}
                onClick={() => handleRoomChange(room)}
              >
                {room.name}
              </div>
            ))
          )}
        </div>

        {/* 在线用户列表 */}
        <UserList
          onlineUserIds={onlineUserIds}
          currentUserId={user.id}
          users={userMap}
        />

        {/* 聊天区域 */}
        {currentRoom ? (
          <div className="chat-room">
            <h3>{currentRoom.name}</h3>
            <div className="messages">
              {messages.map(msg => (
                <div
                  key={msg.id}
                  className={`message ${msg.sender_id === user.id ? 'sent' : 'received'}`}
                >
                  <div style={{ fontSize: '12px', marginBottom: '4px' }}>
                    {msg.sender?.username || `用户${msg.sender_id}`}
                  </div>
                  <div>{msg.content}</div>
                  <div style={{ fontSize: '10px', textAlign: 'right', marginTop: '4px' }}>
                    {new Date(msg.created_at).toLocaleString()}
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
            <form onSubmit={handleSendMessage} className="message-input">
              <input
                type="text"
                placeholder="输入消息..."
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                required
              />
              <button type="submit">发送</button>
            </form>
          </div>
        ) : (
          <div className="chat-room" style={{ justifyContent: 'center', alignItems: 'center' }}>
            <p>请选择一个聊天室开始聊天</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default ChatRoom;
```

#### 20. Dockerfile（chat_app/下）

```Dockerfile

# 构建前端
FROM node:18-alpine as frontend-build
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# 构建后端
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    default-libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

# 复制Python依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制前端构建产物
COPY --from=frontend-build /app/frontend/build ./frontend/build

# 复制项目文件
COPY . .

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

### 部署和运行说明

#### 1. 环境准备

- 安装Docker和Docker Compose

- 安装MySQL（或使用Docker运行MySQL）

- 创建名为`chat_app`的MySQL数据库

#### 2. 修改配置

- 修改`database.py`中的`SQLALCHEMY_DATABASE_URL`，适配你的MySQL连接信息（用户名、密码、地址）

- 修改`auth_service.py`中的`SECRET_KEY`（生产环境使用随机强密钥）

#### 3. 运行方式

##### 方式1：Docker部署（推荐）

```Bash

# 进入项目目录
cd chat_app

# 构建镜像
docker build -t chat-app .

# 运行容器
docker run -d -p 8000:8000 --name chat-app-container chat-app
```

##### 方式2：本地运行

```Bash

# 后端运行
cd chat_app
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 前端运行（新开终端）
cd chat_app/frontend
npm install
npm start
```

#### 4. 访问应用

- 前端访问地址：[http://localhost:8000](http://localhost:8000)

- API文档地址：[http://localhost:8000/docs](http://localhost:8000/docs)

---

### 总结

1. **核心功能实现**：

    - 基于JWT的用户认证系统，密码加密存储，确保安全性

    - 聊天室的创建/成员管理，消息的持久化存储

    - WebSocket实现实时消息收发和在线用户列表更新

    - React+TSX前端界面，支持响应式设计

2. **技术栈关键点**：

    - 后端：FastAPI（异步处理）+ SQLAlchemy（ORM）+ MySQL（存储）+ WebSocket（实时通信）

    - 前端：React+TypeScript，WebSocket API实时通信

    - 部署：Docker容器化，一键构建和运行

3. **扩展建议**：

    - 生产环境需替换JWT密钥为环境变量，配置HTTPS

    - 增加消息类型（图片、文件）、用户头像、房间权限管理等功能

    - 优化WebSocket重连机制，增加消息未读标记
> （注：文档部分内容可能由 AI 生成）