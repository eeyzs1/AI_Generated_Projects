from sqlalchemy.orm import Session
from models.room import Room
from models.user import User
from models.message import Message
from schemas.room import RoomCreate, RoomInvite
from schemas.message import MessageCreate
from fastapi import HTTPException, status

def create_room(db: Session, room: RoomCreate, creator_id: int):
    db_room = Room(name=room.name, creator_id=creator_id)
    db.add(db_room)
    db.commit()
    db.refresh(db_room)
    
    # Add creator as member
    creator = db.query(User).filter(User.id == creator_id).first()
    if creator:
        db_room.members.append(creator)
        db.commit()
    
    return db_room

def get_rooms_by_user(db: Session, user_id: int):
    return db.query(Room).join(Room.members).filter(User.id == user_id).all()

def get_room_by_id(db: Session, room_id: int):
    return db.query(Room).filter(Room.id == room_id).first()

def invite_user_to_room(db: Session, room_id: int, invite_data: RoomInvite, current_user_id: int):
    room = get_room_by_id(db, room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # Check if current user is member of the room
    if current_user_id not in [member.id for member in room.members]:
        raise HTTPException(status_code=403, detail="Not authorized to invite users to this room")
    
    user = db.query(User).filter(User.id == invite_data.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if user is already in room
    if user in room.members:
        raise HTTPException(status_code=400, detail="User is already in this room")
    
    room.members.append(user)
    db.commit()
    db.refresh(room)
    return room

def send_message(db: Session, message: MessageCreate, sender_id: int):
    room = get_room_by_id(db, message.room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # Check if sender is member of the room
    if sender_id not in [member.id for member in room.members]:
        raise HTTPException(status_code=403, detail="Not authorized to send message to this room")
    
    db_message = Message(
        content=message.content,
        sender_id=sender_id,
        room_id=message.room_id
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    return db_message

def get_messages_by_room(db: Session, room_id: int, skip: int = 0, limit: int = 100):
    room = get_room_by_id(db, room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    return db.query(Message).filter(Message.room_id == room_id).order_by(Message.created_at.desc()).offset(skip).limit(limit).all()

def get_online_users(db: Session):
    return db.query(User).filter(User.is_online == True).all()

def set_user_online_status(db: Session, user_id: int, is_online: bool):
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.is_online = is_online
        db.commit()
        db.refresh(user)
    return user