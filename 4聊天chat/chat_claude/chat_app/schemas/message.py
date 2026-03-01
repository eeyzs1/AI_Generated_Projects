from pydantic import BaseModel
from datetime import datetime
from schemas.user import UserSummary


class MessageCreate(BaseModel):
    content: str


class MessageOut(BaseModel):
    id: int
    content: str
    sender: UserSummary
    room_id: int
    created_at: datetime

    class Config:
        from_attributes = True
