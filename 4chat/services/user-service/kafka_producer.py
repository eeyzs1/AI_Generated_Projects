from aiokafka import AIOKafkaProducer
import json, os

KAFKA_BOOTSTRAP_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
_producer = None

async def get_producer() -> AIOKafkaProducer:
    global _producer
    if _producer is None:
        _producer = AIOKafkaProducer(bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS)
        await _producer.start()
    return _producer

async def publish(topic: str, data: dict):
    try:
        p = await get_producer()
        await p.send_and_wait(topic, json.dumps(data).encode())
    except Exception as e:
        print(f"Kafka publish error: {e}")
