from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional

class RoomBase(BaseModel):
    name: str

class RoomCreate(RoomBase):
    pass

class RoomResponse(RoomBase):
    id: int
    created_at: datetime
    creator_id: int

    class Config:
        orm_mode = True
