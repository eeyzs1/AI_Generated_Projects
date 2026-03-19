from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from uuid import UUID

class SenderInfo(BaseModel):
    id: int
    username: str
    displayname: str
    avatar: Optional[str] = None

class MessageBase(BaseModel):
    content: str
    room_id: int

class MessageCreate(MessageBase):
    pass

class Message(MessageBase):
    id: UUID
    sender_id: int
    created_at: datetime
    sender: Optional[SenderInfo] = None

    class Config:
        from_attributes = True
