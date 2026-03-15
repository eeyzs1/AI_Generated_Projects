from sqlalchemy.orm import Session
from models.contact import contact, contactStatus
from models.user import User
from schemas.contact import contactCreate
from fastapi import HTTPException, status

# 发送联系人请求
def send_contact_request(db: Session, contact: contactCreate, sender_id: int):
    # 检查是否是自己
    if sender_id == contact.receiver_id:
        return None
    
    # 检查接收者是否存在
    receiver = db.query(User).filter(User.id == contact.receiver_id).first()
    if not receiver:
        return None
    
    # 检查是否已经存在联系人关系
    existing_contact = db.query(contact).filter(
        ((contact.sender_id == sender_id) & (contact.receiver_id == contact.receiver_id)) |
        ((contact.sender_id == contact.receiver_id) & (contact.receiver_id == sender_id))
    ).first()
    
    if existing_contact:
        return None
    
    # 创建联系人请求
    db_contact = contact(
        sender_id=sender_id,
        receiver_id=contact.receiver_id,
        status=contactStatus.PENDING
    )
    db.add(db_contact)
    db.commit()
    db.refresh(db_contact)
    return db_contact

# 获取用户收到的联系人请求
def get_user_contact_requests(db: Session, user_id: int):
    requests = db.query(contact).filter(
        contact.receiver_id == user_id,
        contact.status == contactStatus.PENDING
    ).all()
    return requests

# 处理联系人请求
def handle_contact_request(db: Session, request_id: int, user_id: int, action: str):
    # 获取联系人请求
    contact_obj = db.query(contact).filter(
        contact.id == request_id,
        contact.receiver_id == user_id,
        contact.status == contactStatus.PENDING
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

# 获取用户的联系人列表
def get_user_contacts(db: Session, user_id: int):
    # 查询用户作为发送者且状态为已接受的联系人关系
    sent_contacts = db.query(User).join(
        contact, contact.receiver_id == User.id
    ).filter(
        contact.sender_id == user_id,
        contact.status == contactStatus.ACCEPTED
    ).all()
    
    # 查询用户作为接收者且状态为已接受的联系人关系
    received_contacts = db.query(User).join(
        contact, contact.sender_id == User.id
    ).filter(
        contact.receiver_id == user_id,
        contact.status == contactStatus.ACCEPTED
    ).all()
    
    # 合并并去重
    contacts = list(set(sent_contacts + received_contacts))
    return contacts

# 删除联系人
def remove_contact(db: Session, user_id: int, contact_id: int):
    # 查找联系人关系
    contact_obj = db.query(contact).filter(
        ((contact.sender_id == user_id) & (contact.receiver_id == contact_id)) |
        ((contact.sender_id == contact_id) & (contact.receiver_id == user_id))
    ).first()
    
    if not contact_obj:
        return None
    
    db.delete(contact_obj)
    db.commit()
    return True

# 搜索用户
def search_users(db: Session, query: str, current_user_id: int):
    users = db.query(User).filter(
        (User.username.ilike(f"%{query}%") | User.displayname.ilike(f"%{query}%")),
        User.id != current_user_id
    ).all()
    return users