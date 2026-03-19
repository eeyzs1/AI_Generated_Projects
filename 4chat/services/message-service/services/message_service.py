import uuid
import datetime
from cassandra.query import SimpleStatement
from database import get_session
from schemas.message import MessageCreate


def save_message(message: MessageCreate, sender_id: int) -> dict:
    session = get_session()
    msg_id = uuid.uuid4()
    created_at = datetime.datetime.utcnow()
    session.execute(
        """
        INSERT INTO messages (room_id, created_at, id, sender_id, content)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (message.room_id, created_at, msg_id, sender_id, message.content)
    )
    return {
        "id": msg_id,
        "room_id": message.room_id,
        "sender_id": sender_id,
        "content": message.content,
        "created_at": created_at,
    }


def get_room_messages(room_id: int, limit: int = 100) -> list:
    session = get_session()
    rows = session.execute(
        "SELECT id, room_id, sender_id, content, created_at FROM messages WHERE room_id = %s LIMIT %s",
        (room_id, limit)
    )
    return [
        {
            "id": row.id,
            "room_id": row.room_id,
            "sender_id": row.sender_id,
            "content": row.content,
            "created_at": row.created_at,
        }
        for row in rows
    ]
