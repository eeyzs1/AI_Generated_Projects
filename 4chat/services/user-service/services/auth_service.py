from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from models.user import User
from models.refresh_token import RefreshToken
from schemas.user import TokenData
import secrets
import os

ALGORITHM = os.environ.get("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.environ.get("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:3000")

class KeyManagementService:
    def __init__(self):
        self.access_keys: List[Dict[str, Any]] = []
        self.refresh_keys: List[Dict[str, Any]] = []
        self._initialize_keys()

    def _initialize_keys(self):
        access_key = os.environ.get("ACCESS_SECRET_KEY", secrets.token_urlsafe(32))
        refresh_key = os.environ.get("REFRESH_SECRET_KEY", secrets.token_urlsafe(32))
        self.access_keys.append({"key": access_key, "created_at": datetime.utcnow(), "is_active": True})
        self.refresh_keys.append({"key": refresh_key, "created_at": datetime.utcnow(), "is_active": True})

    def generate_new_key(self, key_type: str):
        new_key = secrets.token_urlsafe(32)
        entry = {"key": new_key, "created_at": datetime.utcnow(), "is_active": True}
        if key_type == "access":
            self.access_keys.append(entry)
        else:
            self.refresh_keys.append(entry)
        return new_key

    def get_active_keys(self, key_type: str):
        keys = self.access_keys if key_type == "access" else self.refresh_keys
        return [k for k in keys if k["is_active"]]

    def get_latest_key(self, key_type: str):
        keys = self.access_keys if key_type == "access" else self.refresh_keys
        if not keys:
            return self.generate_new_key(key_type)
        return sorted(keys, key=lambda x: x["created_at"], reverse=True)[0]["key"]

    def deactivate_old_keys(self, key_type: str):
        keys = self.access_keys if key_type == "access" else self.refresh_keys
        if len(keys) > 1:
            latest = self.get_latest_key(key_type)
            for k in keys:
                if k["key"] != latest:
                    k["is_active"] = False

    def delete_old_keys(self, key_type: str):
        if key_type == "access":
            self.access_keys = [k for k in self.access_keys if k["is_active"]]
        else:
            self.refresh_keys = [k for k in self.refresh_keys if k["is_active"]]

kms = KeyManagementService()

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password[:72], hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password[:72])

def get_user_by_username(db: Session, username: str):
    return db.query(User).filter(User.username == username).first()

def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()

def get_user_by_verification_token(db: Session, token: str):
    return db.query(User).filter(User.verification_token == token).first()

def get_user_by_reset_token(db: Session, token: str):
    return db.query(User).filter(User.reset_token == token).first()

def authenticate_user(db: Session, username: str, password: str):
    user = get_user_by_username(db, username)
    if not user:
        return None, "Username not found"
    if not user.email_verified:
        return None, "Email not verified"
    if not verify_password(password, user.password_hash):
        return None, "Incorrect password"
    return user, None

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, kms.get_latest_key("access"), algorithm=ALGORITHM)

def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS))
    jti = secrets.token_urlsafe(32)
    to_encode.update({"exp": expire, "type": "refresh", "jti": jti})
    return jwt.encode(to_encode, kms.get_latest_key("refresh"), algorithm=ALGORITHM), jti

def verify_token(token: str, credentials_exception, token_type: str = "access"):
    for key_info in kms.get_active_keys(token_type):
        try:
            payload = jwt.decode(token, key_info["key"], algorithms=[ALGORITHM])
            user_id = payload.get("sub")
            if user_id is None or payload.get("type") != token_type:
                raise credentials_exception
            return TokenData(user_id=int(user_id)), payload
        except JWTError:
            continue
    raise credentials_exception

def store_refresh_token(db: Session, user_id: int, token: str, jti: str, expires_at: datetime):
    db.query(RefreshToken).filter(RefreshToken.user_id == user_id).delete()
    rt = RefreshToken(user_id=user_id, token=token, jti=jti, expires_at=expires_at)
    db.add(rt)
    db.commit()
    return rt

def verify_refresh_token(db: Session, token: str, credentials_exception):
    token_data, payload = verify_token(token, credentials_exception, "refresh")
    jti = payload.get("jti")
    if not jti:
        raise credentials_exception
    rt = db.query(RefreshToken).filter(RefreshToken.jti == jti).first()
    if not rt or rt.revoked or rt.expires_at < datetime.utcnow():
        raise credentials_exception
    return token_data

def revoke_refresh_token(db: Session, user_id: int):
    db.query(RefreshToken).filter(RefreshToken.user_id == user_id).update({"revoked": True})
    db.commit()

def send_verification_email(user: User):
    from services.common.celery_tasks import send_verification_email_task
    token = secrets.token_urlsafe(32)
    user.verification_token = token
    user.verification_expiry = datetime.utcnow() + timedelta(hours=24)
    link = f"{FRONTEND_URL}/verify-email?token={token}"
    body = f"<h1>Verify your email</h1><p><a href='{link}'>Verify Email</a></p><p>Expires in 24 hours.</p>"
    send_verification_email_task.delay(user.email, "Verify your email", body)
    return True

def send_password_reset_email(user: User):
    from services.common.celery_tasks import send_password_reset_email_task
    token = secrets.token_urlsafe(32)
    user.reset_token = token
    user.reset_expiry = datetime.utcnow() + timedelta(hours=1)
    link = f"{FRONTEND_URL}/reset-password?token={token}"
    body = f"<h1>Reset your password</h1><p><a href='{link}'>Reset Password</a></p><p>Expires in 1 hour.</p>"
    send_password_reset_email_task.delay(user.email, "Reset your password", body)
    return True
