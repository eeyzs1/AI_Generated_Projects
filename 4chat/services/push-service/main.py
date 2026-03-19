from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import asyncio, os

from services.kafka_consumer import consume_messages
from nacos_client import register_service

app = FastAPI(title="Push Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

@app.on_event("startup")
async def startup_event():
    register_service("push-service",
                     os.environ.get("SERVICE_HOST", "push-service"),
                     int(os.environ.get("SERVICE_PORT", "8005")))
    asyncio.create_task(consume_messages())

@app.get("/health")
def health():
    return {"status": "ok", "service": "push-service"}
