from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from schemas.user import UserResponse

# 消息发送请求模型
class MessageCreate(BaseModel):
    room_id: int
    content: str = Field(min_length=1, max_length=500)

# 消息响应模型
class MessageResponse(BaseModel):
    id: int
    sender_id: int
    room_id: int
    content: str
    created_at: datetime
    sender: Optional[UserResponse] = None

    class Config:
        from_attributes = True
