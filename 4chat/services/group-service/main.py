from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List
import httpx, os, asyncio

from database import get_db, engine, Base
from models.room import Room, room_members, RoomInvitation
from schemas.room import (RoomCreate, Room as RoomSchema, RoomInvitationCreate,
                           RoomInvitation as RoomInvitationSchema, RoomInvitationResponse,
                           InvitationAction, MemberInfo)
from services.chat_service import (
    create_room, get_user_rooms, get_room, add_user_to_room, is_user_in_room,
    get_room_member_ids, send_invitation, get_user_invitations, handle_invitation
)
from auth import get_current_user_id
from nacos_client import register_service, get_service_url

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Group Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

def get_user_service_url():
    return get_service_url("user-service", "USER_SERVICE_URL")

@app.on_event("startup")
async def startup_event():
    register_service("group-service",
                     os.environ.get("SERVICE_HOST", "group-service"),
                     int(os.environ.get("SERVICE_PORT", "8002")))

@app.get("/health")
def health():
    return {"status": "ok", "service": "group-service"}

async def fetch_user_info(user_id: int) -> dict:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{get_user_service_url()}/internal/users/{user_id}")
            if r.status_code == 200:
                return r.json()
    except Exception:
        pass
    return {"id": user_id, "username": "unknown", "displayname": "Unknown", "avatar": None}

async def fetch_members(member_ids: List[int]) -> List[MemberInfo]:
    infos = await asyncio.gather(*[fetch_user_info(uid) for uid in member_ids])
    return [MemberInfo(**i) for i in infos]

# ── Rooms ───────────────────────────────────────────────────────

@app.post("/api/group/rooms", response_model=RoomSchema)
async def create_new_room(room: RoomCreate, request: Request, db: Session = Depends(get_db)):
    user_id = await get_current_user_id(request)
    db_room = create_room(db, room, user_id)
    db_room.members = await fetch_members([user_id])
    return db_room

@app.get("/api/group/rooms", response_model=List[RoomSchema])
async def get_rooms(request: Request, db: Session = Depends(get_db)):
    user_id = await get_current_user_id(request)
    rooms = get_user_rooms(db, user_id)
    for room in rooms:
        room.members = await fetch_members(get_room_member_ids(db, room.id))
    return rooms

@app.get("/api/group/rooms/{room_id}", response_model=RoomSchema)
async def get_room_detail(room_id: int, request: Request, db: Session = Depends(get_db)):
    user_id = await get_current_user_id(request)
    room = get_room(db, room_id)
    if not room:
        raise HTTPException(404, "Room not found")
    if not is_user_in_room(db, room_id, user_id):
        raise HTTPException(403, "You are not a member of this room")
    room.members = await fetch_members(get_room_member_ids(db, room_id))
    return room

@app.post("/api/group/rooms/{room_id}/add/{target_user_id}")
async def add_user(room_id: int, target_user_id: int, request: Request, db: Session = Depends(get_db)):
    await get_current_user_id(request)
    if not get_room(db, room_id):
        raise HTTPException(404, "Room not found")
    if not add_user_to_room(db, room_id, target_user_id):
        raise HTTPException(400, "User is already in the room")
    return {"detail": "User added to room successfully"}

@app.get("/api/group/rooms/{room_id}/members")
async def get_members(room_id: int, request: Request, db: Session = Depends(get_db)):
    user_id = await get_current_user_id(request)
    if not is_user_in_room(db, room_id, user_id):
        raise HTTPException(403, "You are not a member of this room")
    return await fetch_members(get_room_member_ids(db, room_id))

# ── Invitations ─────────────────────────────────────────────────

@app.post("/api/group/invitations", response_model=RoomInvitationSchema)
async def send_new_invitation(inv: RoomInvitationCreate, request: Request, db: Session = Depends(get_db)):
    user_id = await get_current_user_id(request)
    result = send_invitation(db, inv, user_id)
    if not result:
        raise HTTPException(400, "Invitation failed")
    return result

@app.get("/api/group/invitations", response_model=List[RoomInvitationResponse])
async def get_invitations(request: Request, db: Session = Depends(get_db)):
    user_id = await get_current_user_id(request)
    invitations = get_user_invitations(db, user_id)
    result = []
    for inv in invitations:
        room = get_room(db, inv.room_id)
        inviter = await fetch_user_info(inv.inviter_id)
        result.append(RoomInvitationResponse(
            id=inv.id, room_id=inv.room_id,
            room_name=room.name if room else "Unknown Room",
            inviter_id=inv.inviter_id,
            inviter_name=inviter.get("username", "Unknown"),
            status=inv.status, created_at=inv.created_at
        ))
    return result

@app.post("/api/group/invitations/{invitation_id}/action")
async def handle_invitation_action(invitation_id: int, action: InvitationAction,
                                    request: Request, db: Session = Depends(get_db)):
    user_id = await get_current_user_id(request)
    if action.action not in ("accepted", "rejected"):
        raise HTTPException(400, "Invalid action")
    if not handle_invitation(db, invitation_id, user_id, action.action):
        raise HTTPException(404, "Invitation not found or already processed")
    return {"detail": f"Invitation {action.action}"}

# ── Internal ────────────────────────────────────────────────────

@app.get("/internal/rooms/{room_id}/check-member/{user_id}")
def check_member(room_id: int, user_id: int, db: Session = Depends(get_db)):
    return {"is_member": is_user_in_room(db, room_id, user_id)}

@app.get("/internal/rooms/{room_id}/members")
def get_member_ids(room_id: int, db: Session = Depends(get_db)):
    return {"member_ids": get_room_member_ids(db, room_id)}
