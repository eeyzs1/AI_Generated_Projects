from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from .user import UserResponse

class RoomBase(BaseModel):
    name: str

class RoomCreate(RoomBase):
    pass

class RoomResponse(RoomBase):
    id: int
    creator_id: int
    created_at: datetime
    members: List[UserResponse] = []
    
    class Config:
        from_attributes = True

class RoomInvite(BaseModel):
    user_id: int