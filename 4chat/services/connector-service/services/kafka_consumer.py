from aiokafka import AIOKafkaConsumer
import json, os, asyncio, httpx, sys

KAFKA_BOOTSTRAP_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from nacos_client import get_service_url

def get_group_service_url():
    return get_service_url("group-service", "GROUP_SERVICE_URL")

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
    from services.ws_service import send_to_user
    consumer = AIOKafkaConsumer(
        "msg_sent",
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        group_id="connector-service",
        value_deserializer=lambda v: json.loads(v.decode())
    )
    await consumer.start()
    try:
        async for msg in consumer:
            data = msg.value
            room_id = data.get("room_id")
            if not room_id:
                continue
            member_ids = await get_room_members(room_id)
            sender_id = data.get("sender_id")
            tasks = [
                send_to_user(uid, data)
                for uid in member_ids
                if uid != sender_id
            ]
            if tasks:
                await asyncio.gather(*tasks, return_exceptions=True)
    finally:
        await consumer.stop()
