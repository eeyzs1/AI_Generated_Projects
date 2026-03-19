from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class contactBase(BaseModel):
    receiver_id: int

class contactCreate(contactBase):
    pass

class contact(contactBase):
    id: int
    sender_id: int
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class contactResponse(BaseModel):
    id: int
    sender_id: int
    sender_username: str
    sender_displayname: str
    sender_avatar: Optional[str]
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class ContactResponse(BaseModel):
    id: int
    username: str
    displayname: str
    avatar: Optional[str]

    class Config:
        from_attributes = True

class contactAction(BaseModel):
    action: str
