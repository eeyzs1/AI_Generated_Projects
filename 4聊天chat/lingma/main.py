from fastapi import FastAPI, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List
import json
from datetime import datetime

from database import engine, get_db, Base
from models.user import User
from models.room import Room
from models.message import Message
from schemas.user import UserCreate, UserLogin, UserResponse, Token
from schemas.room import RoomCreate, RoomResponse, RoomInvite
from schemas.message import MessageCreate, MessageResponse
from services.auth_service import (
    authenticate_user, create_access_token, get_current_active_user,
    get_password_hash, ACCESS_TOKEN_EXPIRE_MINUTES, timedelta
)
from services.chat_service import (
    create_room, get_rooms_by_user, invite_user_to_room, send_message,
    get_messages_by_room, get_online_users, set_user_online_status
)
from services.ws_service import manager

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Chat App API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Authentication routes
@app.post("/register", response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    # Check if username already exists
    db_user = db.query(User).filter(User.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # Check if email already exists
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Create new user
    hashed_password = get_password_hash(user.password)
    db_user = User(username=user.username, email=user.email, hashed_password=hashed_password)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.post("/login", response_model=Token)
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = authenticate_user(db, user.username, user.password)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": db_user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

# User routes
@app.get("/users/me", response_model=UserResponse)
def read_users_me(current_user: User = Depends(get_current_active_user)):
    return current_user

@app.get("/users/online", response_model=List[UserResponse])
def get_online_users_list(db: Session = Depends(get_db)):
    return get_online_users(db)

# Room routes
@app.post("/rooms", response_model=RoomResponse)
def create_new_room(
    room: RoomCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return create_room(db, room, current_user.id)

@app.get("/rooms", response_model=List[RoomResponse])
def get_user_rooms(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return get_rooms_by_user(db, current_user.id)

@app.post("/rooms/{room_id}/invite")
def invite_user(
    room_id: int,
    invite_data: RoomInvite,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return invite_user_to_room(db, room_id, invite_data, current_user.id)

# Message routes
@app.post("/messages", response_model=MessageResponse)
def send_new_message(
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return send_message(db, message, current_user.id)

@app.get("/messages/room/{room_id}", response_model=List[MessageResponse])
def get_room_messages(
    room_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    # Verify user has access to room
    room = db.query(Room).join(Room.members).filter(
        Room.id == room_id,
        User.id == current_user.id
    ).first()
    
    if not room:
        raise HTTPException(status_code=403, detail="Not authorized to access this room")
    
    return get_messages_by_room(db, room_id, skip, limit)

# WebSocket endpoint
@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: int, db: Session = Depends(get_db)):
    # Verify user exists and is active
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        await websocket.close(code=4001)
        return
    
    await manager.connect(websocket, user_id)
    set_user_online_status(db, user_id, True)
    
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            if message_data.get("type") == "message":
                # Handle message sending
                room_id = message_data.get("room_id")
                content = message_data.get("content")
                
                if room_id and content:
                    # Save message to database
                    message_create = MessageCreate(content=content, room_id=room_id)
                    db_message = send_message(db, message_create, user_id)
                    
                    # Broadcast message to room members
                    message_response = {
                        "type": "message",
                        "id": db_message.id,
                        "content": db_message.content,
                        "sender_id": db_message.sender_id,
                        "room_id": db_message.room_id,
                        "created_at": db_message.created_at.isoformat(),
                        "sender": {
                            "id": user.id,
                            "username": user.username
                        }
                    }
                    await manager.broadcast_to_room(
                        json.dumps(message_response),
                        room_id,
                        exclude_user=user_id
                    )
                    
            elif message_data.get("type") == "join_room":
                room_id = message_data.get("room_id")
                if room_id:
                    manager.user_rooms[user_id] = room_id
                    
    except WebSocketDisconnect:
        was_last_connection = manager.disconnect(websocket, user_id)
        if was_last_connection:
            set_user_online_status(db, user_id, False)
            await manager.broadcast_user_status(user_id, False)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)