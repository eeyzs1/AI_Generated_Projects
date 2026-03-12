from pydantic import BaseModel
from datetime import datetime
from schemas.user import User

class MessageBase(BaseModel):
    content: str
    room_id: int

class MessageCreate(MessageBase):
    pass

class Message(MessageBase):
    id: int
    sender_id: int
    created_at: datetime
    sender: User | None = None
    
    class Config:
        from_attributes = True