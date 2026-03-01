from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

from .user import UserResponse

class RoomBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)

class RoomCreate(RoomBase):
    pass

class RoomMemberResponse(BaseModel):
    id: int
    user_id: int
    joined_at: datetime
    is_admin: bool
    user: UserResponse

    class Config:
        from_attributes = True

class RoomResponse(RoomBase):
    id: int
    creator_id: int
    created_at: datetime
    members: List[RoomMemberResponse] = []

    class Config:
        from_attributes = True

class RoomInvite(BaseModel):
    user_id: int