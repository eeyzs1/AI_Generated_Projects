from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional
from schemas.user import UserResponse

# 房间创建请求模型
class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)

# 房间成员添加请求模型
class RoomAddMember(BaseModel):
    room_id: int
    user_id: int

# 房间响应模型
class RoomResponse(BaseModel):
    id: int
    name: str
    creator_id: int
    created_at: datetime
    members: Optional[List[UserResponse]] = []

    class Config:
        from_attributes = True
