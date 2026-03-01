from sqlalchemy.orm import Session
from models.room import Room as RoomModel
from models.user import User as UserModel
from models.message import Message as MessageModel
from schemas.room import RoomCreate
from typing import List

def create_room(db: Session, room: RoomCreate, creator_id: int):
    """Create a new chat room with creator as initial member"""
    db_room = RoomModel(name=room.name, creator_id=creator_id)
    db.add(db_room)
    db.flush()  # Get ID without committing
    
    # Add creator to room
    creator = db.query(UserModel).filter(UserModel.id == creator_id).first()
    db_room.users.append(creator)
    db.commit()
    db.refresh(db_room)
    return db_room

def add_user_to_room(db: Session, room_id: int, user_id: int):
    """Add a user to a chat room"""
    room = db.query(RoomModel).filter(RoomModel.id == room_id).first()
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    
    if user not in room.users:
        room.users.append(user)
        db.commit()

def send_message(db: Session, room_id: int, sender_id: int, content: str):
    """Send a message in a room after validating user access"""
    room = db.query(RoomModel).filter(RoomModel.id == room_id).first()
    sender = db.query(UserModel).filter(UserModel.id == sender_id).first()
    
    if sender not in room.users:
        raise Exception("User not in room")
    
    message = MessageModel(content=content, sender_id=sender_id, room_id=room_id)
    db.add(message)
    db.commit()
    db.refresh(message)
    return message
