from typing import List
from fastapi import HTTPException
from sqlalchemy.orm import Session, joinedload
from models.room import Room
from models.user import User
from models.message import Message
from schemas.room import RoomCreate
from schemas.message import MessageCreate


def create_room(db: Session, data: RoomCreate, current_user: User) -> Room:
    if db.query(Room).filter(Room.name == data.name).first():
        raise HTTPException(status_code=400, detail="Room name already exists")
    room = Room(name=data.name, creator_id=current_user.id)
    room.members.append(current_user)
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


def get_room(db: Session, room_id: int) -> Room:
    room = db.query(Room).options(joinedload(Room.members)).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def ensure_membership(room: Room, user: User, db: Session) -> Room:
    if user not in room.members:
        room.members.append(user)
        db.commit()
        db.refresh(room)
    return room


def list_rooms(db: Session) -> List[Room]:
    return db.query(Room).options(joinedload(Room.members)).order_by(Room.created_at.desc()).all()


def create_message(db: Session, room: Room, user: User, data: MessageCreate) -> Message:
    if user not in room.members:
        raise HTTPException(status_code=403, detail="Not a member of this room")
    msg = Message(content=data.content, sender_id=user.id, room_id=room.id)
    db.add(msg)
    db.commit()
    db.refresh(msg)
    db.refresh(msg, ["sender"])
    return msg


def list_messages(db: Session, room: Room, limit: int = 50) -> List[Message]:
    return (
        db.query(Message)
        .options(joinedload(Message.sender))
        .filter(Message.room_id == room.id)
        .order_by(Message.created_at.asc())
        .limit(limit)
        .all()
    )
