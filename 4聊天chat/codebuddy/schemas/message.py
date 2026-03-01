from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class MessageBase(BaseModel):
    room_id: int
    content: str


class MessageCreate(MessageBase):
    pass


class MessageResponse(MessageBase):
    id: int
    sender_id: int
    sender_username: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class WSMessage(BaseModel):
    type: str  # "message", "user_join", "user_leave"
    data: dict
