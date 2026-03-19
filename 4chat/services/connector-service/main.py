from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
import asyncio, os

from auth import get_current_user_id_from_token
from services.ws_service import connect, disconnect
from services.kafka_consumer import consume_messages
from nacos_client import register_service

app = FastAPI(title="Connector Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

@app.on_event("startup")
async def startup_event():
    register_service("connector-service",
                     os.environ.get("SERVICE_HOST", "connector-service"),
                     int(os.environ.get("SERVICE_PORT", "8004")))
    asyncio.create_task(consume_messages())

@app.get("/health")
def health():
    return {"status": "ok", "service": "connector-service"}

@app.websocket("/ws/connect")
async def websocket_endpoint(ws: WebSocket, token: str = Query(...), user_id: int = Query(...)):
    verified_id = await get_current_user_id_from_token(token)
    if verified_id != user_id:
        await ws.close(code=4001)
        return
    await connect(user_id, ws)
    try:
        while True:
            await ws.receive_text()  # keep connection alive, ignore client messages
    except WebSocketDisconnect:
        await disconnect(user_id)
