from typing import List

from fastapi import HTTPException, status
from sqlalchemy.orm import Session, joinedload

from models.message import Message
from models.room import Room
from models.user import User
from schemas.message import MessageCreate
from schemas.room import RoomCreate


def create_room(db: Session, data: RoomCreate, current_user: User) -> Room:
    existing = db.query(Room).filter(Room.name == data.name).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Room name already exists")
    room = Room(name=data.name, creator_id=current_user.id)
    room.members.append(current_user)
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


def get_room(db: Session, room_id: int) -> Room:
    room = (
        db.query(Room)
        .options(joinedload(Room.members))
        .filter(Room.id == room_id)
        .first()
    )
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    return room


def ensure_membership(room: Room, user: User, db: Session) -> None:
    if user not in room.members:
        room.members.append(user)
        db.add(room)
        db.commit()
        db.refresh(room)


def list_rooms(db: Session) -> List[Room]:
    rooms = db.query(Room).options(joinedload(Room.members)).order_by(Room.created_at.desc()).all()
    return rooms


def create_message(db: Session, room: Room, user: User, data: MessageCreate) -> Message:
    if user not in room.members:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
    message = Message(content=data.content, sender_id=user.id, room_id=room.id)
    db.add(message)
    db.commit()
    db.refresh(message)
    return message


def list_messages(db: Session, room: Room, limit: int = 50) -> List[Message]:
    if limit <= 0:
        limit = 50
    return (
        db.query(Message)
        .options(joinedload(Message.sender))
        .filter(Message.room_id == room.id)
        .order_by(Message.created_at.asc())
        .limit(limit)
        .all()
    )
