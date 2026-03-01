from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from .user import UserResponse

class MessageBase(BaseModel):
    content: str

class MessageCreate(MessageBase):
    pass

class MessageResponse(MessageBase):
    id: int
    sender_id: int
    room_id: int
    created_at: datetime
    is_read: bool
    sender: Optional[UserResponse] = None

    class Config:
        from_attributes = True

class WebSocketMessage(BaseModel):
    type: str  # "message", "user_joined", "user_left", "typing"
    data: dict