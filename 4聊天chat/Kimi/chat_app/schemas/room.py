from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional
from schemas.user import UserInRoom


class RoomBase(BaseModel):
    name: str
    description: Optional[str] = None


class RoomCreate(RoomBase):
    member_ids: List[int] = []
    is_group: int = 1


class RoomUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    member_ids: Optional[List[int]] = None


class RoomResponse(RoomBase):
    id: int
    creator_id: int
    is_group: int
    created_at: datetime
    members: List[UserInRoom] = []

    class Config:
        from_attributes = True


class RoomListResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    is_group: int
    member_count: int
    unread_count: int = 0
    last_message: Optional[str] = None
    last_message_time: Optional[datetime] = None

    class Config:
        from_attributes = True
