from pydantic import BaseModel
from datetime import datetime
from typing import List


class RoomBase(BaseModel):
    name: str


class RoomCreate(RoomBase):
    pass


class RoomResponse(RoomBase):
    id: int
    creator_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class RoomDetail(RoomResponse):
    members: List[int] = []

    class Config:
        from_attributes = True


class AddMember(BaseModel):
    room_id: int
    user_id: int
