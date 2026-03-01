from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List
import json
from datetime import datetime

from database import engine, get_db
from models.user import User as UserModel
from models.room import Room as RoomModel
from models.message import Message as MessageModel
from schemas.user import UserCreate, UserLogin, UserResponse
from schemas.room import RoomCreate, RoomResponse
from schemas.message import MessageCreate, MessageResponse
from services.auth_service import create_access_token, verify_password, get_current_user
from services.chat_service import create_room, add_user_to_room, send_message
from services.ws_service import ConnectionManager

app = FastAPI(title="Chat Application", description="A WeChat-like chat application")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize database tables
UserModel.metadata.create_all(bind=engine)
RoomModel.metadata.create_all(bind=engine)
MessageModel.metadata.create_all(bind=engine)

manager = ConnectionManager()

@app.post("/register", response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    existing_user = db.query(UserModel).filter(UserModel.username == user.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already exists")
    
    hashed_password = verify_password(user.password)
    db_user = UserModel(username=user.username, email=user.email, hashed_password=hashed_password)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    """Login and return JWT token"""
    db_user = db.query(UserModel).filter(UserModel.username == user.username).first()
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    access_token = create_access_token(data={"sub": db_user.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=UserResponse)
def read_users_me(current_user: UserModel = Depends(get_current_user)):
    """Get current user info"""
    return current_user

@app.post("/rooms", response_model=RoomResponse)
def create_new_room(room: RoomCreate, current_user: UserModel = Depends(get_current_user), db: Session = Depends(get_db)):
    """Create a new chat room"""
    return create_room(db=db, room=room, creator_id=current_user.id)

@app.get("/rooms", response_model=List[RoomResponse])
def get_rooms(current_user: UserModel = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get all rooms for current user"""
    rooms = db.query(RoomModel).join(RoomModel.users).filter(UserModel.id == current_user.id).all()
    return rooms

@app.post("/rooms/{room_id}/messages", response_model=MessageResponse)
def send_new_message(room_id: int, message: MessageCreate, 
                     current_user: UserModel = Depends(get_current_user), 
                     db: Session = Depends(get_db)):
    """Send a message in a room"""
    return send_message(db=db, room_id=room_id, sender_id=current_user.id, content=message.content)

@app.get("/rooms/{room_id}/messages", response_model=List[MessageResponse])
def get_messages(room_id: int, current_user: UserModel = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get messages from a room"""
    # Verify user has access to room
    room = db.query(RoomModel).filter(RoomModel.id == room_id).first()
    if not room or current_user not in room.users:
        raise HTTPException(status_code=403, detail="Not authorized to access this room")
    
    messages = db.query(MessageModel).filter(MessageModel.room_id == room_id).order_by(MessageModel.timestamp.asc()).all()
    return messages

@app.websocket("/ws/{username}")
async def websocket_endpoint(websocket: WebSocket, username: str):
    """WebSocket endpoint for real-time communication"""
    await manager.connect(websocket, username)
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            # Handle different message types
            if message_data["type"] == "message":
                # Broadcast message to room
                await manager.broadcast_to_room(
                    room_name=message_data["room"],
                    message={
                        "type": "message",
                        "sender": username,
                        "content": message_data["content"],
                        "timestamp": datetime.now().isoformat(),
                        "room": message_data["room"]
                    }
                )
            elif message_data["type"] == "join_room":
                # Add user to room
                await manager.add_user_to_room(message_data["room"], username)
                # Notify others in room about new user
                await manager.broadcast_to_room(
                    room_name=message_data["room"],
                    message={
                        "type": "user_joined",
                        "user": username,
                        "room": message_data["room"]
                    }
                )
            elif message_data["type"] == "leave_room":
                # Remove user from room
                await manager.remove_user_from_room(message_data["room"], username)
                # Notify others in room about leaving user
                await manager.broadcast_to_room(
                    room_name=message_data["room"],
                    message={
                        "type": "user_left",
                        "user": username,
                        "room": message_data["room"]
                    }
                )
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, username)
        # Update online users list
        await manager.broadcast_online_users()
