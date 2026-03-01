from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from .user import UserResponse

class MessageBase(BaseModel):
    content: str

class MessageCreate(MessageBase):
    room_id: int

class MessageResponse(MessageBase):
    id: int
    sender_id: int
    room_id: int
    created_at: datetime
    sender: Optional[UserResponse] = None
    
    class Config:
        from_attributes = True