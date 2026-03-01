from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from schemas.user import UserInRoom


class MessageBase(BaseModel):
    content: str
    message_type: str = "text"


class MessageCreate(MessageBase):
    room_id: int


class MessageResponse(MessageBase):
    id: int
    sender_id: int
    room_id: int
    is_read: int
    created_at: datetime
    sender: Optional[UserInRoom] = None

    class Config:
        from_attributes = True


class MessageHistory(BaseModel):
    messages: list
    total: int
    page: int
    page_size: int


class WebSocketMessage(BaseModel):
    type: str  # message, join, leave, typing, online_users
    data: dict
