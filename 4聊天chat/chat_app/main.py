from fastapi import FastAPI, Depends, HTTPException, status, WebSocket, WebSocketDisconnect, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from datetime import timedelta, datetime
from typing import List, Optional
import json
import os
import uuid
from dotenv import load_dotenv

# 加载.env文件
load_dotenv()

from database import get_db, engine, Base
from models.user import User
from models.room import Room
from models.message import Message
from schemas.user import UserCreate, User as UserSchema, Token, UserLogin, PasswordResetRequest, PasswordReset
from schemas.room import RoomCreate, Room as RoomSchema, RoomInvitationCreate, RoomInvitation, RoomInvitationResponse, InvitationAction
from schemas.message import MessageCreate, Message as MessageSchema
from services.auth_service import (
    get_password_hash, authenticate_user, create_access_token, 
    verify_token, ACCESS_TOKEN_EXPIRE_MINUTES, send_verification_email, 
    send_password_reset_email, get_user_by_verification_token, get_user_by_email, get_user_by_reset_token
)
from services.chat_service import (
    create_room, get_user_rooms, get_room, add_user_to_room,
    send_message, get_room_messages, get_room_members, is_user_in_room,
    send_invitation, get_user_invitations, handle_invitation, get_invitation
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
async def get_current_user(request: Request, db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    auth_header = request.headers.get("Authorization")
    if not auth_header:
        raise credentials_exception
    token = auth_header.split(" ")[1] if len(auth_header.split(" ")) > 1 else None
    if not token:
        raise credentials_exception
    token_data = verify_token(token, credentials_exception)
    user = db.query(User).filter(User.id == token_data.user_id).first()
    if user is None:
        raise credentials_exception
    return user

# 确保头像目录存在
if not os.path.exists("static/avatars"):
    os.makedirs("static/avatars")

# 配置静态文件服务
app.mount("/static", StaticFiles(directory="static"), name="static")

# 用户注册
@app.post("/register")
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
        displayname=user.displayname,
        email=user.email,
        password_hash=hashed_password,
        avatar=user.avatar,
        email_verified=False
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # 发送验证邮件
    send_verification_email(db_user)
    db.commit()
    
    return {"message": "Registration successful. Please check your email to verify your account."}

# 邮箱验证
@app.get("/verify-email")
def verify_email(token: str, db: Session = Depends(get_db)):
    user = get_user_by_verification_token(db, token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid or expired token"
        )
    
    if user.verification_expiry < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token has expired"
        )
    
    user.email_verified = True
    user.verification_token = None
    user.verification_expiry = None
    db.commit()
    
    return {"message": "Email verified successfully. You can now login."}

# 密码重置请求
@app.post("/reset-password-request")
def reset_password_request(request: PasswordResetRequest, db: Session = Depends(get_db)):
    user = get_user_by_email(db, request.email)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email not found"
        )
    
    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please verify your email first"
        )
    
    # 发送密码重置邮件
    send_password_reset_email(user)
    db.commit()
    
    return {"message": "Password reset email sent. Please check your inbox."}

# 密码重置
@app.post("/reset-password")
def reset_password(token: str, password: PasswordReset, db: Session = Depends(get_db)):
    user = get_user_by_reset_token(db, token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid or expired token"
        )
    
    if user.reset_expiry < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token has expired"
        )
    
    # 更新密码
    user.password_hash = get_password_hash(password.password)
    user.reset_token = None
    user.reset_expiry = None
    db.commit()
    
    return {"message": "Password reset successful. You can now login with your new password."}

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

# 上传头像（用于注册时，不需要认证，但添加简单的限制）
@app.post("/upload-avatar/register")
async def upload_avatar_register(file: UploadFile = File(...)):
    # 验证文件类型
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only image files are allowed"
        )
    # 验证文件大小
    contents = await file.read()
    if len(contents) > 2 * 1024 * 1024:  # 2MB
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size must be less than 2MB"
        )
    # 生成唯一文件名
    filename = f"{uuid.uuid4()}_{file.filename}"
    file_path = os.path.join("static/avatars", filename)
    # 保存文件
    with open(file_path, "wb") as f:
        f.write(contents)
    # 返回文件路径
    return {"avatar_url": f"/static/avatars/{filename}"}

# 上传头像（用于已登录用户，需要认证）
@app.post("/upload-avatar")
async def upload_avatar(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    # 验证文件类型
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only image files are allowed"
        )
    # 验证文件大小
    contents = await file.read()
    if len(contents) > 2 * 1024 * 1024:  # 2MB
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size must be less than 2MB"
        )
    # 生成唯一文件名
    filename = f"{uuid.uuid4()}_{file.filename}"
    file_path = os.path.join("static/avatars", filename)
    # 保存文件
    with open(file_path, "wb") as f:
        f.write(contents)
    # 返回文件路径
    return {"avatar_url": f"/static/avatars/{filename}"}

# 更新用户信息
@app.put("/users/me", response_model=UserSchema)
def update_user_me(user_update: UserCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # 检查用户名是否已被其他用户使用
    if user_update.username != current_user.username:
        db_user = db.query(User).filter(User.username == user_update.username).first()
        if db_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already registered"
            )
    # 检查邮箱是否已被其他用户使用
    if user_update.email != current_user.email:
        db_user = db.query(User).filter(User.email == user_update.email).first()
        if db_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
    # 更新用户信息
    current_user.username = user_update.username
    current_user.displayname = user_update.displayname
    current_user.email = user_update.email
    if user_update.avatar:
        current_user.avatar = user_update.avatar
    if user_update.password:
        current_user.password_hash = get_password_hash(user_update.password)
    db.commit()
    db.refresh(current_user)
    return current_user

# 根据username获取用户信息
@app.get("/users/{username}", response_model=UserSchema)
def get_user_by_username(username: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    return user

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
        # 获取在线用户的详细信息
        db = next(get_db())
        online_users_with_info = []
        for user_id in online_users:
            user = db.query(User).filter(User.id == user_id).first()
            if user:
                online_users_with_info.append({
                    "id": user.id,
                    "username": user.username,
                    "displayname": user.displayname,
                    "avatar": user.avatar
                })
        await manager.broadcast_to_room(
            json.dumps({"type": "online_users", "users": online_users_with_info}),
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
                    # 获取发送者信息
                    sender = db.query(User).filter(User.id == user_id).first()
                    sender_info = {
                        "id": sender.id,
                        "username": sender.username,
                        "displayname": sender.displayname,
                        "avatar": sender.avatar
                    }
                    # 广播消息到房间
                    await manager.broadcast_to_room(
                        json.dumps({
                            "type": "message",
                            "id": db_message.id,
                            "sender_id": user_id,
                            "sender": sender_info,
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
        # 获取在线用户的详细信息
        db = next(get_db())
        online_users_with_info = []
        for user_id in online_users:
            user = db.query(User).filter(User.id == user_id).first()
            if user:
                online_users_with_info.append({
                    "id": user.id,
                    "username": user.username,
                    "displayname": user.displayname,
                    "avatar": user.avatar
                })
        await manager.broadcast_to_room(
            json.dumps({"type": "online_users", "users": online_users_with_info}),
            0  # 全局房间
        )

# 发送邀请
@app.post("/invitations", response_model=RoomInvitation)
def send_new_invitation(invitation: RoomInvitationCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_invitation = send_invitation(db, invitation, current_user.id)
    if not db_invitation:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invitation failed. Either you're not in the room, the user is already in the room, or there's already a pending invitation."
        )
    return db_invitation

# 获取用户收到的邀请
@app.get("/invitations", response_model=List[RoomInvitationResponse])
def get_invitations(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    invitations = get_user_invitations(db, current_user.id)
    # 转换为响应格式
    response_invitations = []
    for invitation in invitations:
        room = get_room(db, invitation.room_id)
        inviter = db.query(User).filter(User.id == invitation.inviter_id).first()
        response_invitations.append(RoomInvitationResponse(
            id=invitation.id,
            room_id=invitation.room_id,
            room_name=room.name if room else "Unknown Room",
            inviter_id=invitation.inviter_id,
            inviter_name=inviter.username if inviter else "Unknown User",
            status=invitation.status,
            created_at=invitation.created_at
        ))
    return response_invitations

# 处理邀请
@app.post("/invitations/{invitation_id}/action")
def handle_invitation_action(invitation_id: int, action: InvitationAction, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if action.action not in ["accepted", "rejected"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid action. Must be 'accepted' or 'rejected'."
        )
    result = handle_invitation(db, invitation_id, current_user.id, action.action)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invitation not found or already processed"
        )
    return {"detail": f"Invitation {action.action}ed successfully"}

# 根路径
@app.get("/")
def read_root():
    return {"message": "Welcome to Chat App API"}

# 启动服务器
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)