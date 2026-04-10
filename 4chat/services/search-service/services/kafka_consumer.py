from aiokafka import AIOKafkaConsumer
import json, os, asyncio, logging

from services.search_service import index_message, index_user, index_room

logger = logging.getLogger(__name__)

KAFKA_BOOTSTRAP_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")


async def consume_messages():
    consumer = AIOKafkaConsumer(
        "msg_sent",
        "user_updated",
        "room_updated",
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        group_id="search-service",
        value_deserializer=lambda v: json.loads(v.decode())
    )
    await consumer.start()
    try:
        async for msg in consumer:
            data = msg.value
            msg_type = data.get("type", "")
            try:
                if msg_type == "msg_sent":
                    index_message(
                        message_id=data.get("message_id", ""),
                        room_id=data.get("room_id"),
                        sender_id=data.get("sender_id"),
                        content=data.get("content", ""),
                        created_at=data.get("created_at", "")
                    )
                elif msg_type == "user_updated":
                    index_user(
                        user_id=str(data.get("user_id", "")),
                        username=data.get("username", ""),
                        displayname=data.get("displayname", ""),
                        email=data.get("email"),
                        avatar=data.get("avatar"),
                        is_active=data.get("is_active", True)
                    )
                elif msg_type == "room_updated":
                    index_room(
                        room_id=str(data.get("room_id", "")),
                        name=data.get("name", ""),
                        creator_id=data.get("creator_id"),
                        created_at=data.get("created_at")
                    )
            except Exception as e:
                logger.error(f"Error processing Kafka message (type={msg_type}): {e}")
    finally:
        await consumer.stop()
