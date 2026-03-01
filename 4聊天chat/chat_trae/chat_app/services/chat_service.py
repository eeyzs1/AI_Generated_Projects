from sqlalchemy.orm import Session
from models.room import Room, room_members
from models.message import Message
from models.user import User
from schemas.room import RoomCreate
from schemas.message import MessageCreate

# 创建聊天室
def create_room(db: Session, room: RoomCreate, creator_id: int):
    db_room = Room(name=room.name, creator_id=creator_id)
    db.add(db_room)
    db.commit()
    db.refresh(db_room)
    
    # 将创建者添加到聊天室
    db.execute(room_members.insert().values(room_id=db_room.id, user_id=creator_id))
    db.commit()
    
    return db_room

# 获取用户的聊天室列表
def get_user_rooms(db: Session, user_id: int):
    return db.query(Room).join(room_members).filter(room_members.c.user_id == user_id).all()

# 获取聊天室详情
def get_room(db: Session, room_id: int):
    return db.query(Room).filter(Room.id == room_id).first()

# 添加用户到聊天室
def add_user_to_room(db: Session, room_id: int, user_id: int):
    # 检查用户是否已在聊天室中
    existing = db.execute(room_members.select().where(
        room_members.c.room_id == room_id,
        room_members.c.user_id == user_id
    )).scalar()
    
    if not existing:
        db.execute(room_members.insert().values(room_id=room_id, user_id=user_id))
        db.commit()
        return True
    
    return False

# 检查用户是否在聊天室中
def is_user_in_room(db: Session, room_id: int, user_id: int):
    return db.execute(room_members.select().where(
        room_members.c.room_id == room_id,
        room_members.c.user_id == user_id
    )).scalar() is not None

# 发送消息
def send_message(db: Session, message: MessageCreate, sender_id: int):
    # 检查用户是否在聊天室中
    if not is_user_in_room(db, message.room_id, sender_id):
        return None
    
    db_message = Message(
        sender_id=sender_id,
        room_id=message.room_id,
        content=message.content
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    return db_message

# 获取聊天室消息
def get_room_messages(db: Session, room_id: int, skip: int = 0, limit: int = 100):
    return db.query(Message).filter(Message.room_id == room_id).order_by(Message.created_at.desc()).offset(skip).limit(limit).all()

# 获取聊天室成员
def get_room_members(db: Session, room_id: int):
    return db.query(User).join(room_members).filter(room_members.c.room_id == room_id).all()