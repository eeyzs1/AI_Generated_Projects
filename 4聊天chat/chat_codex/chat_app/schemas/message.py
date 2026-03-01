from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from .user import UserSummary


class MessageBase(BaseModel):
    content: str


class MessageCreate(MessageBase):
    pass


class MessageOut(MessageBase):
    id: int
    sender: UserSummary
    room_id: int
    created_at: Optional[datetime]

    class Config:
        from_attributes = True
