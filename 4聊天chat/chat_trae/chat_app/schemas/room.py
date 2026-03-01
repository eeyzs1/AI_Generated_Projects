from pydantic import BaseModel
from datetime import datetime
from schemas.user import User

class RoomBase(BaseModel):
    name: str

class RoomCreate(RoomBase):
    pass

class Room(RoomBase):
    id: int
    creator_id: int
    created_at: datetime
    members: list[User] = []
    
    class Config:
        from_attributes = True