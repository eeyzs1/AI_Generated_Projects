from pydantic import BaseModel
from datetime import datetime
from typing import List
from schemas.user import UserSummary


class RoomCreate(BaseModel):
    name: str


class RoomOut(BaseModel):
    id: int
    name: str
    creator_id: int
    created_at: datetime
    members: List[UserSummary] = []

    class Config:
        from_attributes = True
