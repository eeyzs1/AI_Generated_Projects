from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from models.user import User
from schemas.user import UserCreate, TokenData
import secrets
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os

# 密钥配置
SECRET_KEY = os.environ.get("SECRET_KEY", "your-secret-key")
ALGORITHM = os.environ.get("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

# 邮件配置
SMTP_SERVER = os.environ.get("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "your-email@gmail.com")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "your-email-password")

# 密码加密上下文
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

# 验证密码
def verify_password(plain_password, hashed_password):
    # bcrypt限制密码长度不能超过72字节
    plain_password = plain_password[:72]
    return pwd_context.verify(plain_password, hashed_password)

# 获取密码哈希
def get_password_hash(password):
    # bcrypt限制密码长度不能超过72字节
    password = password[:72]
    return pwd_context.hash(password)

# 根据用户名获取用户
def get_user_by_username(db: Session, username: str):
    return db.query(User).filter(User.username == username).first()

# 根据邮箱获取用户
def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()

# 根据验证令牌获取用户
def get_user_by_verification_token(db: Session, token: str):
    return db.query(User).filter(User.verification_token == token).first()

# 根据重置令牌获取用户
def get_user_by_reset_token(db: Session, token: str):
    return db.query(User).filter(User.reset_token == token).first()

# 验证用户
def authenticate_user(db: Session, username: str, password: str):
    user = get_user_by_username(db, username)
    if not user:
        return False
    if not user.email_verified:
        return False
    if not verify_password(password, user.password_hash):
        return False
    return user

# 创建访问令牌
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# 验证令牌
def verify_token(token: str, credentials_exception):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        token_data = TokenData(user_id=int(user_id))
    except JWTError:
        raise credentials_exception
    return token_data

# 生成验证令牌
def generate_verification_token():
    return secrets.token_urlsafe(32)

# 生成重置令牌
def generate_reset_token():
    return secrets.token_urlsafe(32)

# 发送邮件
def send_email(to_email, subject, body):
    try:
        msg = MIMEMultipart()
        msg["From"] = SMTP_USER
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "html"))
        
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"Error sending email: {e}")
        return False

# 发送验证邮件
def send_verification_email(user: User):
    token = generate_verification_token()
    user.verification_token = token
    user.verification_expiry = datetime.utcnow() + timedelta(hours=24)
    
    verification_link = f"http://localhost:3000/verify-email?token={token}"
    subject = "Verify your email"
    body = f"""
    <h1>Verify your email</h1>
    <p>Please click the link below to verify your email and activate your account:</p>
    <a href="{verification_link}">Verify Email</a>
    <p>This link will expire in 24 hours.</p>
    """
    
    return send_email(user.email, subject, body)

# 发送密码重置邮件
def send_password_reset_email(user: User):
    token = generate_reset_token()
    user.reset_token = token
    user.reset_expiry = datetime.utcnow() + timedelta(hours=1)
    
    reset_link = f"http://localhost:3000/reset-password?token={token}"
    subject = "Reset your password"
    body = f"""
    <h1>Reset your password</h1>
    <p>Please click the link below to reset your password:</p>
    <a href="{reset_link}">Reset Password</a>
    <p>This link will expire in 1 hour.</p>
    """
    
    return send_email(user.email, subject, body)