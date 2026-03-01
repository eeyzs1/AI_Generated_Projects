from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional

# 基础用户模型
class UserBase(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr

# 用户注册请求模型
class UserCreate(UserBase):
    password: str = Field(min_length=6, max_length=100)

# 用户登录请求模型
class UserLogin(BaseModel):
    username: str
    password: str

# 用户响应模型
class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
