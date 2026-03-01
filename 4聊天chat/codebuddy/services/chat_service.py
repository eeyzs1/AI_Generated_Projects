from typing import List, Optional
from sqlalchemy.orm import Session
from ..models import Room, RoomMember, Message, User
from ..schemas import RoomCreate, RoomDetail, MessageCreate, AddMember


def create_room(db: Session, room: RoomCreate, creator_id: int) -> Room:
    """创建聊天室"""
    db_room = Room(name=room.name, creator_id=creator_id)
    db.add(db_room)
    db.commit()
    db.refresh(db_room)

    # 创建者自动加入聊天室
    db_member = RoomMember(room_id=db_room.id, user_id=creator_id)
    db.add(db_member)
    db.commit()

    return db_room


def get_room(db: Session, room_id: int) -> Optional[Room]:
    """获取聊天室"""
    return db.query(Room).filter(Room.id == room_id).first()


def get_user_rooms(db: Session, user_id: int) -> List[Room]:
    """获取用户所在的所有聊天室"""
    return db.query(Room).join(RoomMember).filter(RoomMember.user_id == user_id).all()


def get_room_detail(db: Session, room_id: int) -> Optional[RoomDetail]:
    """获取聊天室详情（包含成员列表）"""
    room = get_room(db, room_id)
    if not room:
        return None

    members = db.query(RoomMember.user_id).filter(RoomMember.room_id == room_id).all()
    member_ids = [m[0] for m in members]

    return RoomDetail(
        id=room.id,
        name=room.name,
        creator_id=room.creator_id,
        created_at=room.created_at,
        members=member_ids
    )


def add_member_to_room(db: Session, add_member: AddMember) -> bool:
    """添加成员到聊天室"""
    # 检查用户是否已在房间中
    existing = db.query(RoomMember).filter(
        RoomMember.room_id == add_member.room_id,
        RoomMember.user_id == add_member.user_id
    ).first()

    if existing:
        return False

    db_member = RoomMember(room_id=add_member.room_id, user_id=add_member.user_id)
    db.add(db_member)
    db.commit()
    return True


def is_room_member(db: Session, room_id: int, user_id: int) -> bool:
    """检查用户是否为聊天室成员"""
    member = db.query(RoomMember).filter(
        RoomMember.room_id == room_id,
        RoomMember.user_id == user_id
    ).first()
    return member is not None


def create_message(db: Session, message: MessageCreate, sender_id: int) -> Optional[Message]:
    """创建消息"""
    # 验证用户是否在聊天室中
    if not is_room_member(db, message.room_id, sender_id):
        return None

    db_message = Message(
        room_id=message.room_id,
        sender_id=sender_id,
        content=message.content
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    return db_message


def get_room_messages(db: Session, room_id: int, limit: int = 50) -> List[Message]:
    """获取聊天室消息"""
    return db.query(Message).filter(
        Message.room_id == room_id
    ).order_by(Message.created_at).limit(limit).all()


def get_all_users(db: Session) -> List[User]:
    """获取所有用户"""
    return db.query(User).all()


def update_user_online_status(db: Session, user_id: int, is_online: int) -> bool:
    """更新用户在线状态"""
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.is_online = is_online
        db.commit()
        return True
    return False
