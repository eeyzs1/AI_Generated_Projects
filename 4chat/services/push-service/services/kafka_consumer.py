from aiokafka import AIOKafkaConsumer
import json, os, asyncio, httpx, sys

KAFKA_BOOTSTRAP_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from nacos_client import get_service_url
from ha_database import get_async_redis_client

def get_user_service_url():
    return get_service_url("user-service", "USER_SERVICE_URL")

def get_group_service_url():
    return get_service_url("group-service", "GROUP_SERVICE_URL")

_redis = None

async def get_redis():
    global _redis
    if _redis is None:
        _redis = await get_async_redis_client()
    return _redis

async def get_user_email(user_id: int) -> str | None:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{get_user_service_url()}/internal/users/{user_id}")
            if r.status_code == 200:
                return r.json().get("email")
    except Exception:
        pass
    return None

async def get_room_members(room_id: int):
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{get_group_service_url()}/internal/rooms/{room_id}/members")
            if r.status_code == 200:
                return r.json()
    except Exception:
        pass
    return []

async def consume_messages():
    from services.push_handler import send_offline_notification
    consumer = AIOKafkaConsumer(
        "msg_sent",
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        group_id="push-service",
        value_deserializer=lambda v: json.loads(v.decode())
    )
    await consumer.start()
    try:
        async for msg in consumer:
            data = msg.value
            room_id = data.get("room_id")
            sender_id = data.get("sender_id")
            content = data.get("content", "")
            sender = data.get("sender", {})
            sender_name = sender.get("displayname", "Someone")
            if not room_id:
                continue
            r = await get_redis()
            member_ids = await get_room_members(room_id)
            for uid in member_ids:
                if uid == sender_id:
                    continue
                is_online = await r.sismember("online_users", uid)
                if not is_online:
                    email = await get_user_email(uid)
                    if email:
                        send_offline_notification(email, sender_name, content)
    finally:
        await consumer.stop()
