from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from ..models.room import Room, RoomMember
from ..models.message import Message
from ..models.user import User
from ..schemas.room import RoomCreate, RoomResponse
from ..schemas.message import MessageCreate, MessageResponse

def create_room(db: Session, room_create: RoomCreate, user_id: int) -> Room:
    """创建聊天室"""
    # 创建聊天室
    db_room = Room(
        name=room_create.name,
        creator_id=user_id
    )
    db.add(db_room)
    db.commit()
    db.refresh(db_room)
    
    # 将创建者添加为管理员
    db_member = RoomMember(
        room_id=db_room.id,
        user_id=user_id,
        is_admin=True
    )
    db.add(db_member)
    db.commit()
    
    return db_room

def get_user_rooms(db: Session, user_id: int) -> List[Room]:
    """获取用户加入的聊天室列表"""
    rooms = db.query(Room).join(RoomMember).filter(RoomMember.user_id == user_id).all()
    return rooms

def get_room(db: Session, room_id: int) -> Optional[Room]:
    """获取聊天室详情"""
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    return room

def join_room(db: Session, room_id: int, user_id: int) -> RoomMember:
    """加入聊天室"""
    # 检查聊天室是否存在
    room = get_room(db, room_id)
    
    # 检查用户是否已经是聊天室成员
    member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.user_id == user_id
    ).first()
    
    if member:
        raise HTTPException(status_code=400, detail="User already in room")
    
    # 添加用户到聊天室
    db_member = RoomMember(
        room_id=room_id,
        user_id=user_id,
        is_admin=False
    )
    db.add(db_member)
    db.commit()
    db.refresh(db_member)
    
    return db_member

def leave_room(db: Session, room_id: int, user_id: int) -> None:
    """离开聊天室"""
    # 检查聊天室是否存在
    room = get_room(db, room_id)
    
    # 检查用户是否是聊天室成员
    member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.user_id == user_id
    ).first()
    
    if not member:
        raise HTTPException(status_code=400, detail="User not in room")
    
    # 检查是否是创建者
    if room.creator_id == user_id:
        raise HTTPException(status_code=400, detail="Creator cannot leave room")
    
    # 从聊天室中移除用户
    db.delete(member)
    db.commit()

def invite_user_to_room(db: Session, room_id: int, user_id: int, invite_user_id: int) -> RoomMember:
    """邀请用户加入聊天室"""
    # 检查聊天室是否存在
    room = get_room(db, room_id)
    
    # 检查当前用户是否是聊天室成员
    current_member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.user_id == user_id
    ).first()
    
    if not current_member:
        raise HTTPException(status_code=400, detail="Current user not in room")
    
    # 检查被邀请用户是否存在
    invite_user = db.query(User).filter(User.id == invite_user_id).first()
    if not invite_user:
        raise HTTPException(status_code=404, detail="User to invite not found")
    
    # 检查被邀请用户是否已经是聊天室成员
    invite_member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.user_id == invite_user_id
    ).first()
    
    if invite_member:
        raise HTTPException(status_code=400, detail="User already in room")
    
    # 添加被邀请用户到聊天室
    db_member = RoomMember(
        room_id=room_id,
        user_id=invite_user_id,
        is_admin=False
    )
    db.add(db_member)
    db.commit()
    db.refresh(db_member)
    
    return db_member

def send_message(db: Session, room_id: int, user_id: int, message_create: MessageCreate) -> Message:
    """发送消息"""
    # 检查聊天室是否存在
    room = get_room(db, room_id)
    
    # 检查用户是否是聊天室成员
    member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.user_id == user_id
    ).first()
    
    if not member:
        raise HTTPException(status_code=400, detail="User not in room")
    
    # 创建消息
    db_message = Message(
        sender_id=user_id,
        room_id=room_id,
        content=message_create.content
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    
    return db_message

def get_room_messages(db: Session, room_id: int, user_id: int, skip: int = 0, limit: int = 100) -> List[Message]:
    """获取聊天室消息"""
    # 检查聊天室是否存在
    room = get_room(db, room_id)
    
    # 检查用户是否是聊天室成员
    member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.user_id == user_id
    ).first()
    
    if not member:
        raise HTTPException(status_code=400, detail="User not in room")
    
    # 获取消息
    messages = db.query(Message).filter(
        Message.room_id == room_id
    ).order_by(Message.created_at.desc()).offset(skip).limit(limit).all()
    
    # 反转消息顺序，使最新的消息在最后
    messages.reverse()
    
    return messages