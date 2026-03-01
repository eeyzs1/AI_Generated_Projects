from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional


class UserBase(BaseModel):
    username: str
    email: EmailStr


class UserCreate(UserBase):
    password: str


class UserLogin(BaseModel):
    username: str
    password: str


class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[EmailStr] = None
    is_online: Optional[bool] = None


class UserResponse(UserBase):
    id: int
    is_active: bool
    is_online: bool
    last_seen: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class UserInRoom(BaseModel):
    id: int
    username: str
    is_online: bool

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse


class TokenData(BaseModel):
    username: Optional[str] = None
