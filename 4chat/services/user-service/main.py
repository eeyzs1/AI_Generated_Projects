from fastapi import FastAPI, Depends, HTTPException, status, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from sqlalchemy.orm import Session
from datetime import timedelta, datetime
from typing import List
import json, os, uuid
import redis as redis_lib

from database import get_db, engine, Base
from ha_database import get_redis_client
from models.user import User
from models.contact import contact
from schemas.user import UserCreate, UserUpdate, User as UserSchema, Token, UserLogin, PasswordResetRequest, PasswordReset
from schemas.contact import contactCreate, contact as contactSchema, ContactResponse, contactAction
from services.auth_service import (
    get_password_hash, authenticate_user, create_access_token, create_refresh_token,
    verify_token, ACCESS_TOKEN_EXPIRE_MINUTES, send_verification_email,
    send_password_reset_email, get_user_by_verification_token, get_user_by_email,
    get_user_by_reset_token, store_refresh_token, verify_refresh_token, revoke_refresh_token
)
from services.contact_service import (
    send_contact_request, get_user_contact_requests, handle_contact_request,
    get_user_contacts, remove_contact, search_users
)
from nacos_client import register_service

Base.metadata.create_all(bind=engine)

app = FastAPI(title="User Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

AVATAR_UPLOAD_DIR = os.environ.get("AVATAR_UPLOAD_DIR", "static/avatars")
os.makedirs(AVATAR_UPLOAD_DIR, exist_ok=True)

redis = get_redis_client()

@app.on_event("startup")
async def startup_event():
    register_service("user-service",
                     os.environ.get("SERVICE_HOST", "user-service"),
                     int(os.environ.get("SERVICE_PORT", "8001")))

@app.get("/health")
def health():
    return {"status": "ok", "service": "user-service"}

async def get_current_user(request: Request, db: Session = Depends(get_db)):
    exc = HTTPException(status_code=401, detail="Could not validate credentials", headers={"WWW-Authenticate": "Bearer"})
    auth_header = request.headers.get("Authorization", "")
    parts = auth_header.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise exc
    token_data, _ = verify_token(parts[1], exc, "access")
    user = db.query(User).filter(User.id == token_data.user_id).first()
    if not user:
        raise exc
    return user

def save_base64_avatar(base64_data: str) -> str:
    import base64, re
    match = re.search(r'^data:image/(\w+);base64,(.*)$', base64_data)
    if not match:
        return None
    ext = match.group(1)
    try:
        data = base64.b64decode(match.group(2))
    except Exception:
        return None
    filename = f"{uuid.uuid4()}.{ext}"
    with open(os.path.join(AVATAR_UPLOAD_DIR, filename), "wb") as f:
        f.write(data)
    return f"/api/storage/static/avatars/{filename}"

# ── Public ─────────────────────────────────────────────────────

@app.post("/api/user/register")
def register(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.username == user.username).first():
        raise HTTPException(400, "Username already registered")
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(400, "Email already registered")
    avatar_url = None
    if user.avatar:
        avatar_url = save_base64_avatar(user.avatar) if user.avatar.startswith("data:image/") else user.avatar
    db_user = User(username=user.username, displayname=user.displayname, email=user.email,
                   password_hash=get_password_hash(user.password), avatar=avatar_url, email_verified=False)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    send_verification_email(db_user)
    db.commit()
    return {"message": "Registration successful. Please check your email to verify your account."}

@app.get("/api/user/verify-email")
def verify_email(token: str, db: Session = Depends(get_db)):
    user = get_user_by_verification_token(db, token)
    if not user:
        raise HTTPException(404, "Invalid or expired token")
    if user.verification_expiry < datetime.utcnow():
        raise HTTPException(400, "Token has expired")
    user.email_verified = True
    user.verification_token = None
    user.verification_expiry = None
    db.commit()
    return {"message": "Email verified successfully. You can now login."}

@app.post("/api/user/reset-password-request")
def reset_password_request(req: PasswordResetRequest, db: Session = Depends(get_db)):
    user = get_user_by_email(db, req.email)
    if not user:
        raise HTTPException(404, "Email not found")
    if not user.email_verified:
        raise HTTPException(400, "Please verify your email first")
    send_password_reset_email(user)
    db.commit()
    return {"message": "Password reset email sent."}

@app.post("/api/user/reset-password")
def reset_password(token: str, pwd: PasswordReset, db: Session = Depends(get_db)):
    user = get_user_by_reset_token(db, token)
    if not user:
        raise HTTPException(404, "Invalid or expired token")
    if user.reset_expiry < datetime.utcnow():
        raise HTTPException(400, "Token has expired")
    user.password_hash = get_password_hash(pwd.password)
    user.reset_token = None
    user.reset_expiry = None
    db.commit()
    return {"message": "Password reset successful."}

@app.post("/api/user/login", response_model=Token)
def login(user_login: UserLogin, db: Session = Depends(get_db)):
    user, error = authenticate_user(db, user_login.username, user_login.password)
    if not user:
        raise HTTPException(401, error, headers={"WWW-Authenticate": "Bearer"})
    access_token = create_access_token({"sub": str(user.id)}, timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    refresh_token, jti = create_refresh_token({"sub": str(user.id)})
    store_refresh_token(db, user.id, refresh_token, jti, datetime.utcnow() + timedelta(days=7))
    resp = JSONResponse({"access_token": access_token, "refresh_token": refresh_token, "token_type": "bearer"})
    resp.set_cookie("refresh_token", refresh_token, httponly=True, secure=False, samesite="lax", max_age=604800, path="/")
    return resp

@app.post("/api/user/refresh-token", response_model=Token)
def refresh_token_endpoint(request: Request, db: Session = Depends(get_db)):
    rt = request.cookies.get("refresh_token")
    if not rt:
        raise HTTPException(401, "No refresh token provided")
    exc = HTTPException(401, "Could not validate credentials")
    token_data = verify_refresh_token(db, rt, exc)
    user = db.query(User).filter(User.id == token_data.user_id).first()
    if not user:
        raise exc
    access_token = create_access_token({"sub": str(user.id)}, timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    resp = JSONResponse({"access_token": access_token, "refresh_token": rt, "token_type": "bearer"})
    resp.set_cookie("refresh_token", rt, httponly=True, secure=False, samesite="lax", max_age=604800, path="/")
    return resp

# ── Authenticated ───────────────────────────────────────────────

@app.get("/api/user/me", response_model=UserSchema)
def read_me(current_user: User = Depends(get_current_user)):
    return current_user

@app.post("/api/user/logout")
def logout(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    revoke_refresh_token(db, current_user.id)
    redis.delete(f"user:{current_user.id}")
    resp = Response(content=json.dumps({"message": "Logout successful"}), media_type="application/json")
    resp.delete_cookie("refresh_token")
    return resp

@app.put("/api/user/me", response_model=UserSchema)
def update_me(user_update: UserUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        if user_update.username != current_user.username and db.query(User).filter(User.username == user_update.username).first():
            raise HTTPException(400, "Username already registered")
        if user_update.email != current_user.email and db.query(User).filter(User.email == user_update.email).first():
            raise HTTPException(400, "Email already registered")
        if user_update.avatar:
            current_user.avatar = save_base64_avatar(user_update.avatar) if user_update.avatar.startswith("data:image/") else user_update.avatar
        current_user.username = user_update.username
        current_user.displayname = user_update.displayname
        current_user.email = user_update.email
        if user_update.password:
            current_user.password_hash = get_password_hash(user_update.password)
        db.commit()
        db.refresh(current_user)
        redis.delete(f"user:{current_user.id}")
        return current_user
    except HTTPException:
        raise
    except Exception:
        db.rollback()
        raise HTTPException(500, "Failed to update user profile")

@app.get("/api/user/search", response_model=List[ContactResponse])
def search_users_endpoint(query: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return search_users(db, query, current_user.id)

@app.get("/api/user/users/{user_id}", response_model=UserSchema)
def get_user_by_id_endpoint(user_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    return user

@app.get("/api/user/{username}", response_model=UserSchema)
def get_user_by_username_endpoint(username: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(404, "User not found")
    return user

# ── Contacts ────────────────────────────────────────────────────

@app.post("/api/user/contact-requests", response_model=contactSchema)
def send_contact_req(contact_data: contactCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result = send_contact_request(db, contact_data, current_user.id)
    if not result:
        raise HTTPException(400, "Contact request failed")
    return result

@app.get("/api/user/contact-requests")
def get_contact_reqs(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    reqs = get_user_contact_requests(db, current_user.id)
    result = []
    for r in reqs:
        sender = db.query(User).filter(User.id == r.sender_id).first()
        result.append({"id": r.id, "sender_id": r.sender_id,
                        "sender_username": sender.username if sender else "",
                        "sender_displayname": sender.displayname if sender else "",
                        "sender_avatar": sender.avatar if sender else None,
                        "status": r.status, "created_at": r.created_at.isoformat()})
    return result

@app.post("/api/user/contact-requests/{request_id}/action")
def handle_contact_req(request_id: int, action: contactAction, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not handle_contact_request(db, request_id, current_user.id, action.action):
        raise HTTPException(404, "Contact request not found")
    return {"message": f"Contact request {action.action}"}

@app.get("/api/user/contacts", response_model=List[ContactResponse])
def get_contacts(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return get_user_contacts(db, current_user.id)

@app.delete("/api/user/contacts/{contact_id}")
def delete_contact(contact_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not remove_contact(db, current_user.id, contact_id):
        raise HTTPException(404, "Contact not found")
    return {"message": "Contact removed"}

# ── Internal (service-to-service) ──────────────────────────────

@app.get("/internal/users/{user_id}")
def get_user_internal(user_id: int, db: Session = Depends(get_db)):
    cached = redis.get(f"user:{user_id}")
    if cached:
        return json.loads(cached)
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    data = {"id": user.id, "username": user.username, "displayname": user.displayname,
            "email": user.email, "avatar": user.avatar, "is_active": user.is_active,
            "email_verified": user.email_verified}
    redis.setex(f"user:{user_id}", 300, json.dumps(data))
    return data

@app.post("/internal/users/verify-token")
def verify_token_internal(request: Request):
    exc = HTTPException(401, "Invalid token")
    auth = request.headers.get("Authorization", "")
    parts = auth.split(" ")
    if len(parts) != 2:
        raise exc
    try:
        token_data, _ = verify_token(parts[1], exc, "access")
        return {"user_id": token_data.user_id, "valid": True}
    except Exception:
        raise exc
