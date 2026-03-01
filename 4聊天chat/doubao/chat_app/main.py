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
