from pydantic import BaseModel
from typing import Optional, List


class SearchResultItem(BaseModel):
    id: str
    content: str
    room_id: Optional[int] = None
    sender_id: Optional[int] = None
    created_at: Optional[str] = None
    sender: Optional[dict] = None


class MessageSearchResponse(BaseModel):
    total: int
    from_offset: int
    size: int
    results: List[SearchResultItem]


class UserSearchItem(BaseModel):
    user_id: str
    username: str
    displayname: str
    email: Optional[str] = None
    avatar: Optional[str] = None
    is_active: Optional[bool] = None


class UserSearchResponse(BaseModel):
    total: int
    from_offset: int
    size: int
    results: List[UserSearchItem]


class RoomSearchItem(BaseModel):
    room_id: str
    name: str
    creator_id: Optional[int] = None
    created_at: Optional[str] = None


class RoomSearchResponse(BaseModel):
    total: int
    from_offset: int
    size: int
    results: List[RoomSearchItem]
