from __future__ import annotations

from pathlib import Path
from typing import List

from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

import models  # noqa: F401
from database import get_db, init_database, settings
from schemas.message import MessageCreate, MessageOut
from schemas.room import RoomCreate, RoomOut
from schemas.user import Token, UserCreate, UserLogin, UserOut, UserSummary
from services import auth_service, chat_service
from services.ws_service import manager

BASE_DIR = Path(__file__).resolve().parent
DIST_DIR = BASE_DIR / "frontend" / "dist"
PUBLIC_DIR = BASE_DIR / "frontend" / "public"

app = FastAPI(title="Chat Codex App", version="0.1.0")

allowed_origins = [origin.strip() for origin in settings.cors_allow_origins.split(",") if origin.strip()]
if not allowed_origins:
    allowed_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    init_database()


@app.post("/auth/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register_user(user_in: UserCreate, db: Session = Depends(get_db)) -> UserOut:
    user = auth_service.create_user(db, user_in.username, user_in.email, user_in.password)
    return user


@app.post("/auth/login", response_model=Token)
def login_user(payload: UserLogin, db: Session = Depends(get_db)) -> Token:
    user = auth_service.authenticate_user(db, payload.username, payload.password)
    access_token = auth_service.create_access_token(user)
    return Token(access_token=access_token)


@app.get("/users/me", response_model=UserOut)
def get_me(current_user = Depends(auth_service.get_current_user)) -> UserOut:  # type: ignore
    return current_user


@app.get("/users/online", response_model=List[UserSummary])
def online_users() -> List[UserSummary]:
    data = manager.get_online_users()
    return [UserSummary(**item) for item in data]


@app.post("/rooms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def create_room_endpoint(
    room_in: RoomCreate,
    db: Session = Depends(get_db),
    current_user = Depends(auth_service.get_current_user),  # type: ignore
) -> RoomOut:
    room = chat_service.create_room(db, room_in, current_user)
    return room


@app.get("/rooms", response_model=List[RoomOut])
def list_rooms_endpoint(db: Session = Depends(get_db)) -> List[RoomOut]:
    return chat_service.list_rooms(db)


@app.post("/rooms/{room_id}/join", response_model=RoomOut)
def join_room_endpoint(
    room_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(auth_service.get_current_user),  # type: ignore
) -> RoomOut:
    room = chat_service.get_room(db, room_id)
    chat_service.ensure_membership(room, current_user, db)
    return room


@app.get("/rooms/{room_id}/messages", response_model=List[MessageOut])
def list_messages_endpoint(
    room_id: int,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user = Depends(auth_service.get_current_user),  # type: ignore
) -> List[MessageOut]:
    room = chat_service.get_room(db, room_id)
    if current_user not in room.members:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
    return chat_service.list_messages(db, room, limit)


@app.post("/rooms/{room_id}/messages", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
def post_message_endpoint(
    room_id: int,
    message_in: MessageCreate,
    db: Session = Depends(get_db),
    current_user = Depends(auth_service.get_current_user),  # type: ignore
) -> MessageOut:
    room = chat_service.get_room(db, room_id)
    message = chat_service.create_message(db, room, current_user, message_in)
    return message


@app.websocket("/ws/rooms/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: int) -> None:
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008)
        return
    db = auth_service.get_db_session()
    try:
        user = auth_service.get_current_user_from_token(token, db)
        room = chat_service.get_room(db, room_id)
        chat_service.ensure_membership(room, user, db)
        await websocket.accept()
        manager.add_connection(room_id, websocket, user.id, user.username)
        await websocket.send_json(
            {
                "event": "history",
                "data": [
                    {
                        "id": msg.id,
                        "content": msg.content,
                        "sender": {"id": msg.sender.id, "username": msg.sender.username},
                        "room_id": msg.room_id,
                        "created_at": msg.created_at.isoformat() if msg.created_at else None,
                    }
                    for msg in chat_service.list_messages(db, room, limit=50)
                ],
            }
        )
        await manager.broadcast_room(
            room_id,
            {"event": "users", "data": manager.get_online_users()},
        )
        while True:
            payload = await websocket.receive_json()
            content = (payload.get("content") or "").strip()
            if not content:
                continue
            message = chat_service.create_message(db, room, user, MessageCreate(content=content))
            event_payload = {
                "event": "message",
                "data": {
                    "id": message.id,
                    "content": message.content,
                    "sender": {"id": user.id, "username": user.username},
                    "room_id": message.room_id,
                    "created_at": message.created_at.isoformat() if message.created_at else None,
                },
            }
            await manager.broadcast_room(room_id, event_payload)
    except WebSocketDisconnect:
        pass
    finally:
        manager.remove_connection(room_id, websocket)
        await manager.broadcast_room(
            room_id,
            {"event": "users", "data": manager.get_online_users()},
        )
        db.close()


@app.get("/health", tags=["system"])
def health_check() -> dict:
    return {"status": "ok"}


@app.get("/", include_in_schema=False)
async def serve_spa() -> FileResponse:
    index_file = None
    if DIST_DIR.exists():
        index_file = DIST_DIR / "index.html"
    elif PUBLIC_DIR.exists():
        index_file = PUBLIC_DIR / "index.html"
    if index_file and index_file.exists():
        return FileResponse(index_file)
    raise HTTPException(status_code=404, detail="Frontend not built yet")


if DIST_DIR.exists():
    app.mount("/assets", StaticFiles(directory=DIST_DIR / "assets"), name="assets")
elif PUBLIC_DIR.exists():
    app.mount("/assets", StaticFiles(directory=PUBLIC_DIR), name="assets-dev")
