from typing import List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from models.room import Room, room_members
from models.message import Message
from models.user import User
from schemas.room import RoomCreate, RoomUpdate
from schemas.message import MessageCreate


def create_room(db: Session, room: RoomCreate, creator_id: int) -> Room:
    """创建聊天室"""
    # 创建聊天室
    db_room = Room(
        name=room.name,
        description=room.description,
        creator_id=creator_id,
        is_group=room.is_group
    )
    db.add(db_room)
    db.commit()
    db.refresh(db_room)
    
    # 添加创建者为成员
    creator = db.query(User).filter(User.id == creator_id).first()
    if creator:
        db_room.members.append(creator)
    
    # 添加其他成员
    for member_id in room.member_ids:
        if member_id != creator_id:
            member = db.query(User).filter(User.id == member_id).first()
            if member:
                db_room.members.append(member)
    
    db.commit()
    db.refresh(db_room)
    return db_room


def get_room_by_id(db: Session, room_id: int) -> Optional[Room]:
    """通过ID获取聊天室"""
    return db.query(Room).filter(Room.id == room_id).first()


def get_user_rooms(db: Session, user_id: int) -> List[Room]:
    """获取用户加入的所有聊天室"""
    return db.query(Room).join(room_members).filter(room_members.c.user_id == user_id).all()


def is_room_member(db: Session, room_id: int, user_id: int) -> bool:
    """检查用户是否是聊天室成员"""
    room = get_room_by_id(db, room_id)
    if not room:
        return False
    return any(member.id == user_id for member in room.members)


def add_room_member(db: Session, room_id: int, user_id: int) -> Room:
    """添加成员到聊天室"""
    room = get_room_by_id(db, room_id)
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="聊天室不存在"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    if user not in room.members:
        room.members.append(user)
        db.commit()
        db.refresh(room)
    
    return room


def remove_room_member(db: Session, room_id: int, user_id: int) -> Room:
    """从聊天室移除成员"""
    room = get_room_by_id(db, room_id)
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="聊天室不存在"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if user and user in room.members:
        room.members.remove(user)
        db.commit()
        db.refresh(room)
    
    return room


def create_message(db: Session, message: MessageCreate, sender_id: int) -> Message:
    """创建消息"""
    # 验证用户是否属于该聊天室
    if not is_room_member(db, message.room_id, sender_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="您不是该聊天室的成员"
        )
    
    db_message = Message(
        content=message.content,
        sender_id=sender_id,
        room_id=message.room_id,
        message_type=message.message_type
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    return db_message


def get_room_messages(
    db: Session,
    room_id: int,
    page: int = 1,
    page_size: int = 50
) -> List[Message]:
    """获取聊天室消息历史"""
    offset = (page - 1) * page_size
    messages = db.query(Message).filter(
        Message.room_id == room_id
    ).order_by(
        Message.created_at.desc()
    ).offset(offset).limit(page_size).all()
    
    return list(reversed(messages))


def get_room_message_count(db: Session, room_id: int) -> int:
    """获取聊天室消息总数"""
    return db.query(Message).filter(Message.room_id == room_id).count()


def mark_messages_as_read(db: Session, room_id: int, user_id: int):
    """将消息标记为已读"""
    db.query(Message).filter(
        Message.room_id == room_id,
        Message.sender_id != user_id,
        Message.is_read == 0
    ).update({"is_read": 1})
    db.commit()


def get_unread_message_count(db: Session, room_id: int, user_id: int) -> int:
    """获取未读消息数量"""
    return db.query(Message).filter(
        Message.room_id == room_id,
        Message.sender_id != user_id,
        Message.is_read == 0
    ).count()


def get_last_message(db: Session, room_id: int) -> Optional[Message]:
    """获取最后一条消息"""
    return db.query(Message).filter(
        Message.room_id == room_id
    ).order_by(Message.created_at.desc()).first()


def get_online_users(db: Session) -> List[User]:
    """获取在线用户列表"""
    return db.query(User).filter(User.is_online == True, User.is_active == True).all()


def get_all_users(db: Session, current_user_id: int) -> List[User]:
    """获取所有用户（排除当前用户）"""
    return db.query(User).filter(
        User.id != current_user_id,
        User.is_active == True
    ).all()
