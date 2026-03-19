from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class MemberInfo(BaseModel):
    id: int
    username: str
    displayname: str
    avatar: Optional[str] = None

class RoomBase(BaseModel):
    name: str

class RoomCreate(RoomBase):
    pass

class Room(RoomBase):
    id: int
    creator_id: int
    created_at: datetime
    members: List[MemberInfo] = []

    class Config:
        from_attributes = True

class RoomInvitationBase(BaseModel):
    room_id: int
    invitee_id: int

class RoomInvitationCreate(RoomInvitationBase):
    pass

class RoomInvitation(RoomInvitationBase):
    id: int
    inviter_id: int
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class RoomInvitationResponse(BaseModel):
    id: int
    room_id: int
    room_name: str
    inviter_id: int
    inviter_name: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class InvitationAction(BaseModel):
    action: str
