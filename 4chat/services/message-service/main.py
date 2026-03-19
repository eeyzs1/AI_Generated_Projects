from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from typing import List
import os, asyncio

from database import get_session
from schemas.message import MessageCreate, Message as MessageSchema, SenderInfo
from services.message_service import save_message, get_room_messages
from services.kafka_producer import publish
from auth import get_current_user_id
from nacos_client import register_service, get_service_url

app = FastAPI(title="Message Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

import httpx

def get_user_service_url():
    return get_service_url("user-service", "USER_SERVICE_URL")

def get_group_service_url():
    return get_service_url("group-service", "GROUP_SERVICE_URL")

@app.on_event("startup")
async def startup_event():
    get_session()  # init ScyllaDB keyspace + table
    register_service("message-service",
                     os.environ.get("SERVICE_HOST", "message-service"),
                     int(os.environ.get("SERVICE_PORT", "8003")))

@app.get("/health")
def health():
    return {"status": "ok", "service": "message-service"}

async def check_membership(room_id: int, user_id: int) -> bool:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{get_group_service_url()}/internal/rooms/{room_id}/check-member/{user_id}")
            if r.status_code == 200:
                return r.json().get("is_member", False)
    except Exception:
        pass
    return False

async def fetch_user_info(user_id: int) -> dict:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{get_user_service_url()}/internal/users/{user_id}")
            if r.status_code == 200:
                return r.json()
    except Exception:
        pass
    return {"id": user_id, "username": "unknown", "displayname": "Unknown", "avatar": None}

@app.post("/api/message/send", response_model=MessageSchema)
async def send_message(message: MessageCreate, request: Request):
    user_id = await get_current_user_id(request)
    if not await check_membership(message.room_id, user_id):
        raise HTTPException(403, "You are not a member of this room")
    msg = save_message(message, user_id)
    sender_info = await fetch_user_info(user_id)
    await publish("msg_sent", {
        "type": "msg_sent",
        "message_id": str(msg["id"]),
        "sender_id": user_id,
        "room_id": message.room_id,
        "content": message.content,
        "created_at": msg["created_at"].isoformat(),
        "sender": sender_info
    })
    msg["sender"] = SenderInfo(**sender_info)
    return msg

@app.get("/api/message/rooms/{room_id}/messages", response_model=List[MessageSchema])
async def get_messages(room_id: int, limit: int = 100, request: Request = None):
    user_id = await get_current_user_id(request)
    if not await check_membership(room_id, user_id):
        raise HTTPException(403, "You are not a member of this room")
    messages = get_room_messages(room_id, limit)
    sender_ids = list(set(m["sender_id"] for m in messages))
    infos = await asyncio.gather(*[fetch_user_info(sid) for sid in sender_ids])
    sender_map = {i["id"]: i for i in infos}
    for msg in messages:
        info = sender_map.get(msg["sender_id"], {"id": msg["sender_id"], "username": "unknown",
                                                  "displayname": "Unknown", "avatar": None})
        msg["sender"] = SenderInfo(**info)
    return messages
