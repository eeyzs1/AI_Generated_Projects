import json
from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List
import os

from database import get_db, get_settings, init_database
from models.user import User
from schemas.user import UserCreate, UserLogin, UserOut, Token, UserSummary
from schemas.room import RoomCreate, RoomOut
from schemas.message import MessageCreate, MessageOut
from services.auth_service import (
    create_user, authenticate_user, create_access_token,
    get_current_user, get_current_user_from_token, get_db_session
)
from services.chat_service import (
    create_room, get_room, ensure_membership, list_rooms,
    create_message, list_messages
)
from services.ws_service import manager

app = FastAPI(title="Chat App")

settings = get_settings()
origins = [o.strip() for o in settings.CORS_ALLOW_ORIGINS.split(",")]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    init_database()


# --- Auth ---

@app.post("/auth/register", response_model=UserOut)
def register(data: UserCreate, db: Session = Depends(get_db)):
    return create_user(db, data.username, data.email, data.password)


@app.post("/auth/login", response_model=Token)
def login(data: UserLogin, db: Session = Depends(get_db)):
    user = authenticate_user(db, data.username, data.password)
    return Token(access_token=create_access_token(user))


# --- Users ---

@app.get("/users/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)):
    return current_user


@app.get("/users/online", response_model=List[UserSummary])
def online_users():
    return manager.get_online_users()


# --- Rooms ---

@app.post("/rooms", response_model=RoomOut)
def create_room_endpoint(data: RoomCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return create_room(db, data, current_user)


@app.get("/rooms", response_model=List[RoomOut])
def get_rooms(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return list_rooms(db)


@app.post("/rooms/{room_id}/join", response_model=RoomOut)
def join_room(room_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = get_room(db, room_id)
    return ensure_membership(room, current_user, db)


@app.get("/rooms/{room_id}/messages", response_model=List[MessageOut])
def get_messages(room_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = get_room(db, room_id)
    return list_messages(db, room)


@app.post("/rooms/{room_id}/messages", response_model=MessageOut)
def send_message(room_id: int, data: MessageCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = get_room(db, room_id)
    return create_message(db, room, current_user, data)


@app.get("/health")
def health():
    return {"status": "ok"}


# --- WebSocket ---

@app.websocket("/ws/rooms/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: int, token: str):
    db = get_db_session()
    try:
        current_user = get_current_user_from_token(token, db)
    except HTTPException:
        await websocket.close(code=4001)
        db.close()
        return

    await websocket.accept()
    room = get_room(db, room_id)
    ensure_membership(room, current_user, db)
    await manager.add_connection(room_id, websocket, current_user.id, current_user.username)

    # Send message history
    msgs = list_messages(db, room)
    history = [
        {
            "id": m.id,
            "content": m.content,
            "sender": {"id": m.sender.id, "username": m.sender.username},
            "room_id": m.room_id,
            "created_at": m.created_at.isoformat(),
        }
        for m in msgs
    ]
    await websocket.send_json({"type": "history", "messages": history})

    # Broadcast updated user list
    await manager.broadcast_room(room_id, {"type": "users", "users": manager.get_online_users()})

    try:
        while True:
            raw = await websocket.receive_text()
            data = json.loads(raw)
            content = data.get("content", "").strip()
            if not content:
                continue
            from schemas.message import MessageCreate as MC
            msg = create_message(db, room, current_user, MC(content=content))
            payload = {
                "type": "message",
                "id": msg.id,
                "content": msg.content,
                "sender": {"id": msg.sender.id, "username": msg.sender.username},
                "room_id": msg.room_id,
                "created_at": msg.created_at.isoformat(),
            }
            await manager.broadcast_room(room_id, payload)
    except WebSocketDisconnect:
        manager.remove_connection(room_id, websocket)
        await manager.broadcast_room(room_id, {"type": "users", "users": manager.get_online_users()})
    finally:
        db.close()


# --- SPA fallback ---

frontend_dist = os.path.join(os.path.dirname(__file__), "frontend", "dist")
if os.path.exists(frontend_dist):
    app.mount("/assets", StaticFiles(directory=os.path.join(frontend_dist, "assets")), name="assets")

    @app.get("/{full_path:path}")
    def spa_fallback(full_path: str):
        return FileResponse(os.path.join(frontend_dist, "index.html"))
