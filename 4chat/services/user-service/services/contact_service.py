from sqlalchemy.orm import Session
from models.contact import contact, contactStatus
from models.user import User
from schemas.contact import contactCreate

def send_contact_request(db: Session, contact_data: contactCreate, sender_id: int):
    if sender_id == contact_data.receiver_id:
        return None
    receiver = db.query(User).filter(User.id == contact_data.receiver_id).first()
    if not receiver:
        return None
    existing = db.query(contact).filter(
        ((contact.sender_id == sender_id) & (contact.receiver_id == contact_data.receiver_id)) |
        ((contact.sender_id == contact_data.receiver_id) & (contact.receiver_id == sender_id))
    ).first()
    if existing:
        return None
    db_contact = contact(sender_id=sender_id, receiver_id=contact_data.receiver_id, status=contactStatus.PENDING)
    db.add(db_contact)
    db.commit()
    db.refresh(db_contact)
    return db_contact

def get_user_contact_requests(db: Session, user_id: int):
    return db.query(contact).filter(contact.receiver_id == user_id, contact.status == contactStatus.PENDING).all()

def handle_contact_request(db: Session, request_id: int, user_id: int, action: str):
    contact_obj = db.query(contact).filter(
        contact.id == request_id, contact.receiver_id == user_id, contact.status == contactStatus.PENDING
    ).first()
    if not contact_obj:
        return None
    if action == "accepted":
        contact_obj.status = contactStatus.ACCEPTED
    elif action == "rejected":
        db.delete(contact_obj)
    else:
        return None
    db.commit()
    return True

def get_user_contacts(db: Session, user_id: int):
    sent = db.query(User).join(contact, contact.receiver_id == User.id).filter(
        contact.sender_id == user_id, contact.status == contactStatus.ACCEPTED
    ).all()
    received = db.query(User).join(contact, contact.sender_id == User.id).filter(
        contact.receiver_id == user_id, contact.status == contactStatus.ACCEPTED
    ).all()
    return list(set(sent + received))

def remove_contact(db: Session, user_id: int, contact_id: int):
    contact_obj = db.query(contact).filter(
        ((contact.sender_id == user_id) & (contact.receiver_id == contact_id)) |
        ((contact.sender_id == contact_id) & (contact.receiver_id == user_id))
    ).first()
    if not contact_obj:
        return None
    db.delete(contact_obj)
    db.commit()
    return True

def search_users(db: Session, query: str, current_user_id: int):
    return db.query(User).filter(
        (User.username.ilike(f"%{query}%") | User.displayname.ilike(f"%{query}%")),
        User.id != current_user_id
    ).all()
