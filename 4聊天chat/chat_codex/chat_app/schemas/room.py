from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from .user import UserSummary


class RoomBase(BaseModel):
    name: str


class RoomCreate(RoomBase):
    pass


class RoomOut(RoomBase):
    id: int
    creator_id: Optional[int]
    created_at: Optional[datetime]
    members: List[UserSummary] = Field(default_factory=list)

    class Config:
        from_attributes = True
