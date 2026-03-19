from fastapi import WebSocket
from typing import Dict
import os, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from ha_database import get_async_redis_client

# In-memory map: user_id -> WebSocket (per instance)
_connections: Dict[int, WebSocket] = {}
_redis = None

async def get_redis():
    global _redis
    if _redis is None:
        _redis = await get_async_redis_client()
    return _redis

async def connect(user_id: int, ws: WebSocket):
    await ws.accept()
    _connections[user_id] = ws
    r = await get_redis()
    await r.sadd("online_users", user_id)

async def disconnect(user_id: int):
    _connections.pop(user_id, None)
    r = await get_redis()
    await r.srem("online_users", user_id)

async def send_to_user(user_id: int, data: dict):
    ws = _connections.get(user_id)
    if ws:
        try:
            await ws.send_json(data)
        except Exception:
            await disconnect(user_id)

async def is_online(user_id: int) -> bool:
    r = await get_redis()
    return await r.sismember("online_users", user_id)
