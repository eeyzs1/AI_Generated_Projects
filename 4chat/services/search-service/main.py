from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
import os, asyncio

from database import init_indices
from schemas.search import (
    MessageSearchResponse, SearchResultItem,
    UserSearchResponse, UserSearchItem,
    RoomSearchResponse, RoomSearchItem
)
from services.search_service import search_messages, search_users, search_rooms
from services.kafka_consumer import consume_messages
from auth import get_current_user_id
from nacos_client import register_service

app = FastAPI(title="Search Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])


@app.on_event("startup")
async def startup_event():
    init_indices()
    register_service("search-service",
                     os.environ.get("SERVICE_HOST", "search-service"),
                     int(os.environ.get("SERVICE_PORT", "8007")))
    asyncio.create_task(consume_messages())


@app.get("/health")
def health():
    return {"status": "ok", "service": "search-service"}


@app.get("/api/search/messages", response_model=MessageSearchResponse)
async def search_messages_endpoint(q: str, room_id: Optional[int] = None,
                                   from_offset: int = 0, size: int = 20,
                                   request: Request = None):
    await get_current_user_id(request)
    if size > 100:
        size = 100
    result = search_messages(q, room_id, from_offset, size)
    return result


@app.get("/api/search/users", response_model=UserSearchResponse)
async def search_users_endpoint(q: str, from_offset: int = 0, size: int = 20,
                                request: Request = None):
    await get_current_user_id(request)
    if size > 100:
        size = 100
    result = search_users(q, from_offset, size)
    return result


@app.get("/api/search/rooms", response_model=RoomSearchResponse)
async def search_rooms_endpoint(q: str, from_offset: int = 0, size: int = 20,
                                request: Request = None):
    await get_current_user_id(request)
    if size > 100:
        size = 100
    result = search_rooms(q, from_offset, size)
    return result


@app.post("/api/search/reindex/messages")
async def reindex_messages(request: Request):
    await get_current_user_id(request)
    from services.common.celery_tasks import reindex_messages_task
    task = reindex_messages_task.delay()
    return {"task_id": task.id, "status": "PENDING", "message": "Reindex task submitted"}


@app.post("/api/search/reindex/users")
async def reindex_users(request: Request):
    await get_current_user_id(request)
    from services.common.celery_tasks import reindex_users_task
    task = reindex_users_task.delay()
    return {"task_id": task.id, "status": "PENDING", "message": "Reindex task submitted"}


@app.post("/api/search/reindex/rooms")
async def reindex_rooms(request: Request):
    await get_current_user_id(request)
    from services.common.celery_tasks import reindex_rooms_task
    task = reindex_rooms_task.delay()
    return {"task_id": task.id, "status": "PENDING", "message": "Reindex task submitted"}


@app.get("/api/search/reindex/status/{task_id}")
async def reindex_status(task_id: str, request: Request):
    await get_current_user_id(request)
    from services.common.celery_app import celery_app
    result = celery_app.AsyncResult(task_id)
    response = {"task_id": task_id, "status": result.status}
    if result.ready():
        response["result"] = result.result
    return response
