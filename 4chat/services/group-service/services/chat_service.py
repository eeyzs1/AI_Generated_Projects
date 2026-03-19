from sqlalchemy.orm import Session
from models.room import Room, room_members, RoomInvitation
from schemas.room import RoomCreate, RoomInvitationCreate

def create_room(db: Session, room: RoomCreate, creator_id: int):
    db_room = Room(name=room.name, creator_id=creator_id)
    db.add(db_room)
    db.commit()
    db.refresh(db_room)
    db.execute(room_members.insert().values(room_id=db_room.id, user_id=creator_id))
    db.commit()
    return db_room

def get_user_rooms(db: Session, user_id: int):
    return db.query(Room).join(room_members).filter(room_members.c.user_id == user_id).all()

def get_room(db: Session, room_id: int):
    return db.query(Room).filter(Room.id == room_id).first()

def add_user_to_room(db: Session, room_id: int, user_id: int):
    existing = db.execute(room_members.select().where(
        room_members.c.room_id == room_id,
        room_members.c.user_id == user_id
    )).scalar()
    if not existing:
        db.execute(room_members.insert().values(room_id=room_id, user_id=user_id))
        db.commit()
        return True
    return False

def is_user_in_room(db: Session, room_id: int, user_id: int):
    return db.execute(room_members.select().where(
        room_members.c.room_id == room_id,
        room_members.c.user_id == user_id
    )).scalar() is not None

def get_room_member_ids(db: Session, room_id: int):
    rows = db.execute(room_members.select().where(room_members.c.room_id == room_id)).fetchall()
    return [row.user_id for row in rows]

def send_invitation(db: Session, invitation: RoomInvitationCreate, inviter_id: int):
    if not is_user_in_room(db, invitation.room_id, inviter_id):
        return None
    if is_user_in_room(db, invitation.room_id, invitation.invitee_id):
        return None
    existing = db.query(RoomInvitation).filter(
        RoomInvitation.room_id == invitation.room_id,
        RoomInvitation.invitee_id == invitation.invitee_id,
        RoomInvitation.status == "pending"
    ).first()
    if existing:
        return existing
    db_inv = RoomInvitation(room_id=invitation.room_id, inviter_id=inviter_id,
                             invitee_id=invitation.invitee_id, status="pending")
    db.add(db_inv)
    db.commit()
    db.refresh(db_inv)
    return db_inv

def get_user_invitations(db: Session, user_id: int):
    return db.query(RoomInvitation).filter(RoomInvitation.invitee_id == user_id).all()

def handle_invitation(db: Session, invitation_id: int, user_id: int, action: str):
    inv = db.query(RoomInvitation).filter(
        RoomInvitation.id == invitation_id,
        RoomInvitation.invitee_id == user_id,
        RoomInvitation.status == "pending"
    ).first()
    if not inv:
        return None
    inv.status = action
    db.commit()
    if action == "accepted":
        add_user_to_room(db, inv.room_id, user_id)
    return inv

def get_invitation(db: Session, invitation_id: int):
    return db.query(RoomInvitation).filter(RoomInvitation.id == invitation_id).first()
