from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from models.user import User
from models.refresh_token import RefreshToken
from schemas.user import UserCreate, TokenData
import secrets
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import time

# 密钥配置
ALGORITHM = os.environ.get("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))  # 1小时
REFRESH_TOKEN_EXPIRE_DAYS = int(os.environ.get("REFRESH_TOKEN_EXPIRE_DAYS", "7"))  # 7天

# 密钥管理服务 (KMS)
class KeyManagementService:
    def __init__(self):
        self.access_keys: List[Dict[str, Any]] = []
        self.refresh_keys: List[Dict[str, Any]] = []
        self._initialize_keys()
    
    def _initialize_keys(self):
        # 从环境变量获取初始密钥或生成新密钥
        access_key = os.environ.get("ACCESS_SECRET_KEY", secrets.token_urlsafe(32))
        refresh_key = os.environ.get("REFRESH_SECRET_KEY", secrets.token_urlsafe(32))
        
        self.access_keys.append({
            "key": access_key,
            "created_at": datetime.utcnow(),
            "is_active": True
        })
        
        self.refresh_keys.append({
            "key": refresh_key,
            "created_at": datetime.utcnow(),
            "is_active": True
        })
    
    def generate_new_key(self, key_type: str):
        # 生成新密钥
        new_key = secrets.token_urlsafe(32)
        if key_type == "access":
            self.access_keys.append({
                "key": new_key,
                "created_at": datetime.utcnow(),
                "is_active": True
            })
        else:
            self.refresh_keys.append({
                "key": new_key,
                "created_at": datetime.utcnow(),
                "is_active": True
            })
        return new_key
    
    def get_active_keys(self, key_type: str):
        # 获取所有活跃的密钥
        if key_type == "access":
            return [key for key in self.access_keys if key["is_active"]]
        else:
            return [key for key in self.refresh_keys if key["is_active"]]
    
    def get_latest_key(self, key_type: str):
        # 获取最新的密钥
        if key_type == "access":
            if not self.access_keys:
                return self.generate_new_key("access")
            return sorted(self.access_keys, key=lambda x: x["created_at"], reverse=True)[0]["key"]
        else:
            if not self.refresh_keys:
                return self.generate_new_key("refresh")
            return sorted(self.refresh_keys, key=lambda x: x["created_at"], reverse=True)[0]["key"]
    
    def deactivate_old_keys(self, key_type: str):
        # 停用过期的密钥（所有旧密钥）
        if key_type == "access":
            if len(self.access_keys) > 1:
                # 保留最新的密钥，停用其他所有密钥
                latest_key = self.get_latest_key("access")
                for key in self.access_keys:
                    if key["key"] != latest_key:
                        key["is_active"] = False
        else:
            if len(self.refresh_keys) > 1:
                # 保留最新的密钥，停用其他所有密钥
                latest_key = self.get_latest_key("refresh")
                for key in self.refresh_keys:
                    if key["key"] != latest_key:
                        key["is_active"] = False
    
    def delete_old_keys(self, key_type: str):
        # 删除所有非活跃的密钥
        if key_type == "access":
            self.access_keys = [key for key in self.access_keys if key["is_active"]]
        else:
            self.refresh_keys = [key for key in self.refresh_keys if key["is_active"]]

# 初始化KMS
kms = KeyManagementService()

# 定期更新密钥
import threading
import time

# 从环境变量获取密钥更新频率（小时）
KEY_ROTATION_INTERVAL_HOURS = int(os.environ.get("KEY_ROTATION_INTERVAL_HOURS", "24"))

def rotate_keys_periodically():
    """定期轮换密钥的后台任务"""
    while True:
        try:
            # 执行access密钥更新逻辑
            kms.delete_old_keys("access")
            kms.deactivate_old_keys("access")
            kms.generate_new_key("access")
            
            # 执行refresh密钥更新逻辑
            kms.delete_old_keys("refresh")
            kms.deactivate_old_keys("refresh")
            kms.generate_new_key("refresh")
            
            print(f"Keys rotated at {datetime.utcnow()}")
        except Exception as e:
            print(f"Error rotating keys: {e}")
        
        # 等待指定的时间间隔
        time.sleep(KEY_ROTATION_INTERVAL_HOURS * 3600)

# 启动密钥轮换后台任务
if KEY_ROTATION_INTERVAL_HOURS > 0:
    rotation_thread = threading.Thread(target=rotate_keys_periodically, daemon=True)
    rotation_thread.start()

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
        return None, "Username not found"
    if not user.email_verified:
        return None, "Email not verified"
    if not verify_password(password, user.password_hash):
        return None, "Incorrect password"
    return user, None

# 创建访问令牌
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, kms.get_latest_key("access"), algorithm=ALGORITHM)
    return encoded_jwt

# 创建刷新令牌
def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    # 生成jti（JWT ID）
    jti = secrets.token_urlsafe(32)
    to_encode.update({"exp": expire, "type": "refresh", "jti": jti})
    encoded_jwt = jwt.encode(to_encode, kms.get_latest_key("refresh"), algorithm=ALGORITHM)
    return encoded_jwt, jti

# 验证令牌
def verify_token(token: str, credentials_exception, token_type: str = "access"):
    # 尝试所有活跃的密钥
    active_keys = kms.get_active_keys(token_type)
    for key_info in active_keys:
        try:
            payload = jwt.decode(token, key_info["key"], algorithms=[ALGORITHM])
            user_id: int = payload.get("sub")
            if user_id is None:
                raise credentials_exception
            # 验证token类型
            if payload.get("type") != token_type:
                raise credentials_exception
            token_data = TokenData(user_id=int(user_id))
            return token_data, payload
        except JWTError:
            continue
    # 所有密钥都验证失败
    raise credentials_exception

# 存储刷新令牌
def store_refresh_token(db: Session, user_id: int, token: str, jti: str, expires_at: datetime):
    # 首先删除用户的所有旧刷新令牌
    db.query(RefreshToken).filter(RefreshToken.user_id == user_id).delete()
    # 创建新的刷新令牌记录
    refresh_token = RefreshToken(
        user_id=user_id,
        token=token,
        jti=jti,
        expires_at=expires_at
    )
    db.add(refresh_token)
    db.commit()
    return refresh_token

# 验证刷新令牌
def verify_refresh_token(db: Session, token: str, credentials_exception):
    # 首先验证token格式
    token_data, payload = verify_token(token, credentials_exception, "refresh")
    # 获取jti
    jti = payload.get("jti")
    if not jti:
        raise credentials_exception
    # 从数据库中查找刷新令牌
    refresh_token = db.query(RefreshToken).filter(RefreshToken.jti == jti).first()
    if not refresh_token:
        raise credentials_exception
    # 检查令牌是否已被撤销
    if refresh_token.revoked:
        raise credentials_exception
    # 检查令牌是否已过期
    if refresh_token.expires_at < datetime.utcnow():
        raise credentials_exception
    return token_data

# 撤销刷新令牌
def revoke_refresh_token(db: Session, user_id: int):
    # 撤销用户的所有刷新令牌
    db.query(RefreshToken).filter(RefreshToken.user_id == user_id).update({"revoked": True})
    db.commit()

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