from pydantic import BaseModel, EmailStr
from datetime import datetime

class UserBase(BaseModel):
    username: str
    displayname: str
    email: EmailStr

class UserCreate(UserBase):
    password: str
    avatar: str | None = None

class UserUpdate(UserBase):
    password: str | None = None
    avatar: str | None = None

class UserLogin(BaseModel):
    username: str
    password: str

class User(UserBase):
    id: int
    avatar: str | None
    created_at: datetime
    is_active: bool
    email_verified: bool
    
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: int | None = None

class PasswordResetRequest(BaseModel):
    email: EmailStr

class PasswordReset(BaseModel):
    password: str