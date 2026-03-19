from sqlalchemy import Column, Integer, String, DateTime, Table, ForeignKey
from sqlalchemy.sql import func
from database import Base

# user_id has no FK - users live in im_user DB
room_members = Table('room_members', Base.metadata,
    Column('room_id', Integer, ForeignKey('rooms.id'), primary_key=True),
    Column('user_id', Integer, primary_key=True)
)

class Room(Base):
    __tablename__ = "rooms"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    creator_id = Column(Integer, nullable=False)   # no FK - different DB
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class RoomInvitation(Base):
    __tablename__ = "room_invitations"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey('rooms.id'), nullable=False)
    inviter_id = Column(Integer, nullable=False)   # no FK - different DB
    invitee_id = Column(Integer, nullable=False)   # no FK - different DB
    status = Column(String(20), default="pending")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
