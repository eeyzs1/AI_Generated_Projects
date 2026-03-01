chat_app/
├── main.py
├── models/
│   ├── __init__.py
│   ├── user.py
│   ├── room.py
│   └── message.py
├── schemas/
│   ├── __init__.py
│   ├── user.py
│   ├── room.py
│   └── message.py
├── services/
│   ├── __init__.py
│   ├── auth_service.py
│   ├── chat_service.py
│   └── ws_service.py
├── database.py
├── requirements.txt
└── Dockerfile

chat_app/main.py
from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List
import json
from datetime import datetime

from database import engine, get_db
from models.user import User as UserModel
from models.room import Room as RoomModel
from models.message import Message as MessageModel
from schemas.user import UserCreate, UserLogin, UserResponse
from schemas.room import RoomCreate, RoomResponse
from schemas.message import MessageCreate, MessageResponse
from services.auth_service import create_access_token, verify_password, get_current_user
from services.chat_service import create_room, add_user_to_room, send_message
from services.ws_service import ConnectionManager

app = FastAPI(title="Chat Application", description="A WeChat-like chat application")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize database tables
UserModel.metadata.create_all(bind=engine)
RoomModel.metadata.create_all(bind=engine)
MessageModel.metadata.create_all(bind=engine)

manager = ConnectionManager()

@app.post("/register", response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    existing_user = db.query(UserModel).filter(UserModel.username == user.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already exists")
    
    hashed_password = verify_password(user.password)
    db_user = UserModel(username=user.username, email=user.email, hashed_password=hashed_password)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    """Login and return JWT token"""
    db_user = db.query(UserModel).filter(UserModel.username == user.username).first()
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    access_token = create_access_token(data={"sub": db_user.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=UserResponse)
def read_users_me(current_user: UserModel = Depends(get_current_user)):
    """Get current user info"""
    return current_user

@app.post("/rooms", response_model=RoomResponse)
def create_new_room(room: RoomCreate, current_user: UserModel = Depends(get_current_user), db: Session = Depends(get_db)):
    """Create a new chat room"""
    return create_room(db=db, room=room, creator_id=current_user.id)

@app.get("/rooms", response_model=List[RoomResponse])
def get_rooms(current_user: UserModel = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get all rooms for current user"""
    rooms = db.query(RoomModel).join(RoomModel.users).filter(UserModel.id == current_user.id).all()
    return rooms

@app.post("/rooms/{room_id}/messages", response_model=MessageResponse)
def send_new_message(room_id: int, message: MessageCreate, 
                     current_user: UserModel = Depends(get_current_user), 
                     db: Session = Depends(get_db)):
    """Send a message in a room"""
    return send_message(db=db, room_id=room_id, sender_id=current_user.id, content=message.content)

@app.get("/rooms/{room_id}/messages", response_model=List[MessageResponse])
def get_messages(room_id: int, current_user: UserModel = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get messages from a room"""
    # Verify user has access to room
    room = db.query(RoomModel).filter(RoomModel.id == room_id).first()
    if not room or current_user not in room.users:
        raise HTTPException(status_code=403, detail="Not authorized to access this room")
    
    messages = db.query(MessageModel).filter(MessageModel.room_id == room_id).order_by(MessageModel.timestamp.asc()).all()
    return messages

@app.websocket("/ws/{username}")
async def websocket_endpoint(websocket: WebSocket, username: str):
    """WebSocket endpoint for real-time communication"""
    await manager.connect(websocket, username)
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            # Handle different message types
            if message_data["type"] == "message":
                # Broadcast message to room
                await manager.broadcast_to_room(
                    room_name=message_data["room"],
                    message={
                        "type": "message",
                        "sender": username,
                        "content": message_data["content"],
                        "timestamp": datetime.now().isoformat(),
                        "room": message_data["room"]
                    }
                )
            elif message_data["type"] == "join_room":
                # Add user to room
                await manager.add_user_to_room(message_data["room"], username)
                # Notify others in room about new user
                await manager.broadcast_to_room(
                    room_name=message_data["room"],
                    message={
                        "type": "user_joined",
                        "user": username,
                        "room": message_data["room"]
                    }
                )
            elif message_data["type"] == "leave_room":
                # Remove user from room
                await manager.remove_user_from_room(message_data["room"], username)
                # Notify others in room about leaving user
                await manager.broadcast_to_room(
                    room_name=message_data["room"],
                    message={
                        "type": "user_left",
                        "user": username,
                        "room": message_data["room"]
                    }
                )
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, username)
        # Update online users list
        await manager.broadcast_online_users()

chat_app/models/__init__.py
"""Database models package"""

chat_app/models/user.py
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    rooms = relationship("Room", secondary="room_users", back_populates="users")
    sent_messages = relationship("Message", foreign_keys="Message.sender_id", back_populates="sender")

chat_app/models/room.py
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Table, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

# Association table for many-to-many relationship between Room and User
room_users = Table(
    'room_users',
    Base.metadata,
    Column('room_id', Integer, ForeignKey('rooms.id'), primary_key=True),
    Column('user_id', Integer, ForeignKey('users.id'), primary_key=True)
)

class Room(Base):
    __tablename__ = "rooms"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    creator_id = Column(Integer, ForeignKey('users.id'))

    # Relationships
    creator = relationship("User", back_populates="created_rooms")
    users = relationship("User", secondary=room_users, back_populates="rooms")
    messages = relationship("Message", back_populates="room")

chat_app/models/message.py
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    content = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
    sender_id = Column(Integer, ForeignKey('users.id'))
    room_id = Column(Integer, ForeignKey('rooms.id'))

    # Relationships
    sender = relationship("User", foreign_keys=[sender_id], back_populates="sent_messages")
    room = relationship("Room", back_populates="messages")

chat_app/schemas/__init__.py
"""Pydantic schemas package"""

chat_app/schemas/user.py
from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional

class UserBase(BaseModel):
    username: str
    email: EmailStr

class UserCreate(UserBase):
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class UserResponse(UserBase):
    id: int
    created_at: datetime

    class Config:
        orm_mode = True

chat_app/schemas/room.py
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional

class RoomBase(BaseModel):
    name: str

class RoomCreate(RoomBase):
    pass

class RoomResponse(RoomBase):
    id: int
    created_at: datetime
    creator_id: int

    class Config:
        orm_mode = True

chat_app/schemas/message.py
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class MessageBase(BaseModel):
    content: str

class MessageCreate(MessageBase):
    pass

class MessageResponse(MessageBase):
    id: int
    timestamp: datetime
    sender_id: int
    room_id: int

    class Config:
        orm_mode = True

chat_app/services/__init__.py
"""Service layer package"""

chat_app/services/auth_service.py
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from database import get_db
from models.user import User as UserModel
from config import SECRET_KEY, ALGORITHM

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

def verify_password(plain_password: str, hashed_password: str = None) -> str:
    """Hash password or verify if comparing to stored hash"""
    if hashed_password is None:
        # If no hash provided, just return the hash of plain password
        return pwd_context.hash(plain_password)
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=30)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)) -> UserModel:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = db.query(UserModel).filter(UserModel.username == username).first()
    if user is None:
        raise credentials_exception
    return user

chat_app/services/chat_service.py
from sqlalchemy.orm import Session
from models.room import Room as RoomModel
from models.user import User as UserModel
from models.message import Message as MessageModel
from schemas.room import RoomCreate
from typing import List

def create_room(db: Session, room: RoomCreate, creator_id: int):
    """Create a new chat room with creator as initial member"""
    db_room = RoomModel(name=room.name, creator_id=creator_id)
    db.add(db_room)
    db.flush()  # Get ID without committing
    
    # Add creator to room
    creator = db.query(UserModel).filter(UserModel.id == creator_id).first()
    db_room.users.append(creator)
    db.commit()
    db.refresh(db_room)
    return db_room

def add_user_to_room(db: Session, room_id: int, user_id: int):
    """Add a user to a chat room"""
    room = db.query(RoomModel).filter(RoomModel.id == room_id).first()
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    
    if user not in room.users:
        room.users.append(user)
        db.commit()

def send_message(db: Session, room_id: int, sender_id: int, content: str):
    """Send a message in a room after validating user access"""
    room = db.query(RoomModel).filter(RoomModel.id == room_id).first()
    sender = db.query(UserModel).filter(UserModel.id == sender_id).first()
    
    if sender not in room.users:
        raise Exception("User not in room")
    
    message = MessageModel(content=content, sender_id=sender_id, room_id=room_id)
    db.add(message)
    db.commit()
    db.refresh(message)
    return message

chat_app/services/ws_service.py
from typing import Dict, List
import asyncio
import json

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List] = {}
        self.user_rooms: Dict[str, List[str]] = {}

    async def connect(self, websocket, username: str):
        await websocket.accept()
        
        # Initialize user's room list if not exists
        if username not in self.user_rooms:
            self.user_rooms[username] = []
        
        # Add connection to user's connections
        if username not in self.active_connections:
            self.active_connections[username] = []
        self.active_connections[username].append(websocket)

    def disconnect(self, websocket, username: str):
        if username in self.active_connections:
            self.active_connections[username].remove(websocket)
            if not self.active_connections[username]:
                del self.active_connections[username]
        
        # Remove user from all rooms when they disconnect
        if username in self.user_rooms:
            for room in self.user_rooms[username]:
                if room in self.active_connections:
                    # Notify other users in room that this user left
                    asyncio.create_task(
                        self.broadcast_to_room(
                            room_name=room,
                            message={
                                "type": "user_left",
                                "user": username,
                                "room": room
                            }
                        )
                    )
            del self.user_rooms[username]

    async def broadcast_to_room(self, room_name: str, message: dict):
        """Broadcast a message to all users in a specific room"""
        for username, connections in self.active_connections.items():
            if username in self.user_rooms and room_name in self.user_rooms[username]:
                for connection in connections:
                    try:
                        await connection.send_text(json.dumps(message))
                    except:
                        # If sending fails, remove the connection
                        self.disconnect(connection, username)

    async def send_personal_message(self, message: str, websocket):
        await websocket.send_text(message)

    def add_user_to_room(self, room_name: str, username: str):
        """Add a user to a room"""
        if username not in self.user_rooms:
            self.user_rooms[username] = []
        if room_name not in self.user_rooms[username]:
            self.user_rooms[username].append(room_name)

    def remove_user_from_room(self, room_name: str, username: str):
        """Remove a user from a room"""
        if username in self.user_rooms and room_name in self.user_rooms[username]:
            self.user_rooms[username].remove(room_name)

    async def broadcast_online_users(self):
        """Broadcast updated online users list to all connected users"""
        online_users = list(self.active_connections.keys())
        message = {
            "type": "online_users_update",
            "users": online_users
        }
        
        for connections in self.active_connections.values():
            for connection in connections:
                try:
                    await connection.send_text(json.dumps(message))
                except:
                    continue

chat_app/database.py
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import DATABASE_URL

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

chat_app/config.py
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./chat_app.db")
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

chat_app/requirements.txt
fastapi==0.104.1
uvicorn==0.24.0
sqlalchemy==2.0.23
pydantic==2.5.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dotenv==1.0.0
websockets==12.0

chat_app/Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

chat_app/frontend/public/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WeChat-like Chat App</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</head>
<body>
    <div id="root"></div>
</body>
</html>

chat_app/frontend/src/App.tsx
import React, { useState, useEffect } from 'react';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';
import UserList from './UserList';
import './App.css';

const App: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [activeView, setActiveView] = useState<'login' | 'register' | 'chat'>('login');
  const [token, setToken] = useState<string | null>(localStorage.getItem('token'));

  // Check if user is already logged in
  useEffect(() => {
    const savedToken = localStorage.getItem('token');
    if (savedToken) {
      // Validate token by fetching user info
      fetch('http://localhost:8000/users/me', {
        headers: {
          'Authorization': `Bearer ${savedToken}`
        }
      })
      .then(response => {
        if (response.ok) {
          return response.json();
        }
        throw new Error('Token invalid');
      })
      .then(userData => {
        setCurrentUser(userData);
        setActiveView('chat');
      })
      .catch(() => {
        localStorage.removeItem('token');
        setToken(null);
      });
    }
  }, []);

  const handleLogin = (userData: any, accessToken: string) => {
    setCurrentUser(userData);
    setToken(accessToken);
    localStorage.setItem('token', accessToken);
    setActiveView('chat');
  };

  const handleLogout = () => {
    setCurrentUser(null);
    setToken(null);
    localStorage.removeItem('token');
    setActiveView('login');
  };

  return (
    <div className="app">
      {activeView === 'login' && (
        <Login onLogin={handleLogin} onSwitchToRegister={() => setActiveView('register')} />
      )}
      {activeView === 'register' && (
        <Register onRegister={handleLogin} onSwitchToLogin={() => setActiveView('login')} />
      )}
      {activeView === 'chat' && currentUser && (
        <div className="chat-container">
          <UserList currentUser={currentUser} onLogout={handleLogout} />
          <ChatRoom currentUser={currentUser} token={token!} />
        </div>
      )}
    </div>
  );
};

export default App;

chat_app/frontend/src/Login.tsx
import React, { useState } from 'react';

interface LoginProps {
  onLogin: (userData: any, accessToken: string) => void;
  onSwitchToRegister: () => void;
}

const Login: React.FC<LoginProps> = ({ onLogin, onSwitchToRegister }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const response = await fetch('http://localhost:8000/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password }),
      });

      if (response.ok) {
        const data = await response.json();
        // Get user info using the token
        const userInfoResponse = await fetch('http://localhost:8000/users/me', {
          headers: {
            'Authorization': `Bearer ${data.access_token}`
          }
        });
        const userData = await userInfoResponse.json();
        onLogin(userData, data.access_token);
      } else {
        const errorData = await response.json();
        setError(errorData.detail || 'Login failed');
      }
    } catch (err) {
      setError('An error occurred during login');
    }
  };

  return (
    <div className="auth-container">
      <form onSubmit={handleSubmit} className="auth-form">
        <h2>Login</h2>
        {error && <div className="error">{error}</div>}
        <div className="input-group">
          <label htmlFor="username">Username</label>
          <input
            type="text"
            id="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
        </div>
        <div className="input-group">
          <label htmlFor="password">Password</label>
          <input
            type="password"
            id="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        <button type="submit" className="btn btn-primary">Login</button>
        <p>
          Don't have an account?{' '}
          <button type="button" onClick={onSwitchToRegister} className="link-button">
            Register here
          </button>
        </p>
      </form>
    </div>
  );
};

export default Login;

chat_app/frontend/src/Register.tsx
import React, { useState } from 'react';

interface RegisterProps {
  onRegister: (userData: any, accessToken: string) => void;
  onSwitchToLogin: () => void;
}

const Register: React.FC<RegisterProps> = ({ onRegister, onSwitchToLogin }) => {
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    try {
      const response = await fetch('http://localhost:8000/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, email, password }),
      });

      if (response.ok) {
        const userData = await response.json();
        // Automatically log in after registration
        const loginResponse = await fetch('http://localhost:8000/login', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ username, password }),
        });

        if (loginResponse.ok) {
          const loginData = await loginResponse.json();
          onRegister(userData, loginData.access_token);
        } else {
          setError('Registration successful but login failed');
        }
      } else {
        const errorData = await response.json();
        setError(errorData.detail || 'Registration failed');
      }
    } catch (err) {
      setError('An error occurred during registration');
    }
  };

  return (
    <div className="auth-container">
      <form onSubmit={handleSubmit} className="auth-form">
        <h2>Register</h2>
        {error && <div className="error">{error}</div>}
        <div className="input-group">
          <label htmlFor="reg-username">Username</label>
          <input
            type="text"
            id="reg-username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
        </div>
        <div className="input-group">
          <label htmlFor="reg-email">Email</label>
          <input
            type="email"
            id="reg-email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>
        <div className="input-group">
          <label htmlFor="reg-password">Password</label>
          <input
            type="password"
            id="reg-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        <div className="input-group">
          <label htmlFor="reg-confirm-password">Confirm Password</label>
          <input
            type="password"
            id="reg-confirm-password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            required
          />
        </div>
        <button type="submit" className="btn btn-primary">Register</button>
        <p>
          Already have an account?{' '}
          <button type="button" onClick={onSwitchToLogin} className="link-button">
            Login here
          </button>
        </p>
      </form>
    </div>
  );
};

export default Register;

chat_app/frontend/src/ChatRoom.tsx
import React, { useState, useEffect, useRef } from 'react';

interface ChatRoomProps {
  currentUser: any;
  token: string;
}

interface Message {
  id: number;
  content: string;
  timestamp: string;
  sender_id: number;
  sender_username?: string;
}

const ChatRoom: React.FC<ChatRoomProps> = ({ currentUser, token }) => {
  const [rooms, setRooms] = useState<any[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<any>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Fetch rooms
  useEffect(() => {
    const fetchRooms = async () => {
      try {
        const response = await fetch('http://localhost:8000/rooms', {
          headers: {
            'Authorization': `Bearer ${token}`
          }
        });
        if (response.ok) {
          const data = await response.json();
          setRooms(data);
          if (data.length > 0 && !selectedRoom) {
            setSelectedRoom(data[0]);
          }
        }
      } catch (err) {
        console.error('Failed to fetch rooms:', err);
      }
    };

    fetchRooms();
  }, [token, selectedRoom]);

  // Fetch messages when room changes
  useEffect(() => {
    if (selectedRoom) {
      const fetchMessages = async () => {
        try {
          const response = await fetch(`http://localhost:8000/rooms/${selectedRoom.id}/messages`, {
            headers: {
              'Authorization': `Bearer ${token}`
            }
          });
          if (response.ok) {
            const data = await response.json();
            setMessages(data);
          }
        } catch (err) {
          console.error('Failed to fetch messages:', err);
        }
      };

      fetchMessages();
    }
  }, [selectedRoom, token]);

  // Setup WebSocket connection
  useEffect(() => {
    if (selectedRoom) {
      // Close previous connection if exists
      if (ws) {
        ws.close();
      }

      const socket = new WebSocket(`ws://localhost:8000/ws/${currentUser.username}`);
      
      socket.onopen = () => {
        console.log('Connected to WebSocket');
        // Join the selected room
        socket.send(JSON.stringify({
          type: 'join_room',
          room: selectedRoom.name
        }));
      };
      
      socket.onmessage = (event) => {
        const data = JSON.parse(event.data);
        
        if (data.type === 'message' && data.room === selectedRoom.name) {
          setMessages(prev => [
            ...prev,
            {
              id: Date.now(), // In a real app, this would come from the backend
              content: data.content,
              timestamp: data.timestamp,
              sender_id: data.sender === currentUser.username ? currentUser.id : -1,
              sender_username: data.sender
            }
          ]);
        } else if (data.type === 'user_joined' && data.room === selectedRoom.name) {
          console.log(`${data.user} joined the room`);
        } else if (data.type === 'user_left' && data.room === selectedRoom.name) {
          console.log(`${data.user} left the room`);
        }
      };
      
      socket.onclose = () => {
        console.log('Disconnected from WebSocket');
      };
      
      setWs(socket);
      
      return () => {
        socket.close();
      };
    }
  }, [selectedRoom, currentUser]);

  // Scroll to bottom of messages
  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const handleSendMessage = async () => {
    if (!newMessage.trim() || !selectedRoom || !ws) return;

    // Send via WebSocket
    ws.send(JSON.stringify({
      type: 'message',
      room: selectedRoom.name,
      content: newMessage
    }));

    setNewMessage('');
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  return (
    <div className="chat-room">
      <div className="room-header">
        <h3>{selectedRoom ? selectedRoom.name : 'Select a room'}</h3>
      </div>
      
      <div className="messages-container">
        {messages.map((msg) => (
          <div 
            key={msg.id} 
            className={`message ${msg.sender_id === currentUser.id ? 'own-message' : ''}`}
          >
            <div className="message-content">
              {msg.sender_id !== currentUser.id && (
                <div className="message-sender">{msg.sender_username}</div>
              )}
              <div className="message-text">{msg.content}</div>
              <div className="message-time">{new Date(msg.timestamp).toLocaleTimeString()}</div>
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>
      
      <div className="message-input-container">
        <textarea
          value={newMessage}
          onChange={(e) => setNewMessage(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type your message..."
          className="message-input"
        />
        <button onClick={handleSendMessage} className="send-button">
          <i className="fas fa-paper-plane"></i>
        </button>
      </div>
    </div>
  );
};

export default ChatRoom;

chat_app/frontend/src/UserList.tsx
import React, { useState, useEffect } from 'react';

interface UserListProps {
  currentUser: any;
  onLogout: () => void;
}

const UserList: React.FC<UserListProps> = ({ currentUser, onLogout }) => {
  const [rooms, setRooms] = useState<any[]>([]);
  const [newRoomName, setNewRoomName] = useState('');
  const [loading, setLoading] = useState(false);

  // Fetch rooms
  useEffect(() => {
    const fetchRooms = async () => {
      try {
        const response = await fetch('http://localhost:8000/rooms', {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token')}`
          }
        });
        if (response.ok) {
          const data = await response.json();
          setRooms(data);
        }
      } catch (err) {
        console.error('Failed to fetch rooms:', err);
      }
    };

    fetchRooms();
  }, []);

  const handleCreateRoom = async () => {
    if (!newRoomName.trim()) return;

    setLoading(true);
    try {
      const response = await fetch('http://localhost:8000/rooms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        },
        body: JSON.stringify({ name: newRoomName })
      });

      if (response.ok) {
        const newRoom = await response.json();
        setRooms([...rooms, newRoom]);
        setNewRoomName('');
      } else {
        const errorData = await response.json();
        alert(errorData.detail || 'Failed to create room');
      }
    } catch (err) {
      console.error('Failed to create room:', err);
      alert('Failed to create room');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="user-list">
      <div className="user-info">
        <h3>Welcome, {currentUser.username}!</h3>
        <button onClick={onLogout} className="logout-btn">
          <i className="fas fa-sign-out-alt"></i> Logout
        </button>
      </div>
      
      <div className="rooms-section">
        <h4>Your Rooms</h4>
        <div className="create-room">
          <input
            type="text"
            value={newRoomName}
            onChange={(e) => setNewRoomName(e.target.value)}
            placeholder="New room name"
            className="room-input"
          />
          <button onClick={handleCreateRoom} disabled={loading} className="create-room-btn">
            {loading ? 'Creating...' : 'Create'}
          </button>
        </div>
        <ul className="rooms-list">
          {rooms.map(room => (
            <li key={room.id} className="room-item">
              <i className="fas fa-comments"></i> {room.name}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default UserList;

chat_app/frontend/src/App.css
/* Global styles */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  background-color: #f0f2f5;
}

.app {
  height: 100vh;
  display: flex;
  justify-content: center;
  align-items: center;
}

/* Auth forms */
.auth-container {
  width: 100%;
  max-width: 400px;
  padding: 20px;
}

.auth-form {
  background: white;
  padding: 30px;
  border-radius: 10px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.auth-form h2 {
  text-align: center;
  margin-bottom: 20px;
  color: #333;
}

.input-group {
  margin-bottom: 15px;
}

.input-group label {
  display: block;
  margin-bottom: 5px;
  color: #555;
  font-weight: 500;
}

.input-group input {
  width: 100%;
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 5px;
  font-size: 16px;
}

.btn {
  width: 100%;
  padding: 12px;
  border: none;
  border-radius: 5px;
  font-size: 16px;
  cursor: pointer;
}

.btn-primary {
  background-color: #007bff;
  color: white;
}

.btn-primary:hover {
  background-color: #0056b3;
}

.link-button {
  background: none;
  border: none;
  color: #007bff;
  text-decoration: underline;
  cursor: pointer;
  padding: 0;
  font-size: 14px;
}

.error {
  color: #dc3545;
  margin-bottom: 15px;
  padding: 10px;
  background-color: #f8d7da;
  border-radius: 5px;
  text-align: center;
}

/* Chat container */
.chat-container {
  display: flex;
  height: 90vh;
  width: 95%;
  max-width: 1200px;
  background: white;
  border-radius: 10px;
  overflow: hidden;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

/* User list sidebar */
.user-list {
  width: 250px;
  background: #f8f9fa;
  border-right: 1px solid #dee2e6;
  display: flex;
  flex-direction: column;
}

.user-info {
  padding: 20px;
  border-bottom: 1px solid #dee2e6;
}

.user-info h3 {
  margin-bottom: 15px;
  color: #333;
}

.logout-btn {
  background: #dc3545;
  color: white;
  border: none;
  padding: 8px 12px;
  border-radius: 5px;
  cursor: pointer;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.rooms-section {
  padding: 20px;
  flex-grow: 1;
}

.rooms-section h4 {
  margin-bottom: 15px;
  color: #333;
}

.create-room {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
}

.room-input {
  flex-grow: 1;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 5px;
}

.create-room-btn {
  background: #28a745;
  color: white;
  border: none;
  padding: 8px 12px;
  border-radius: 5px;
  cursor: pointer;
}

.create-room-btn:disabled {
  background: #6c757d;
}

.rooms-list {
  list-style: none;
}

.room-item {
  padding: 10px;
  border-bottom: 1px solid #eee;
  cursor: pointer;
  transition: background 0.2s;
}

.room-item:hover {
  background: #e9ecef;
}

/* Chat room */
.chat-room {
  flex-grow: 1;
  display: flex;
  flex-direction: column;
}

.room-header {
  padding: 15px 20px;
  background: #007bff;
  color: white;
  border-bottom: 1px solid #dee2e6;
}

.messages-container {
  flex-grow: 1;
  padding: 20px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.message {
  max-width: 70%;
  padding: 10px 15px;
  border-radius: 10px;
  position: relative;
}

.own-message {
  align-self: flex-end;
  background-color: #d0ebff;
  border-bottom-right-radius: 0;
}

.message:not(.own-message) {
  align-self: flex-start;
  background-color: #f1f3f5;
  border-bottom-left-radius: 0;
}

.message-sender {
  font-weight: bold;
  font-size: 0.85em;
  margin-bottom: 5px;
  color: #007bff;
}

.message-text {
  word-wrap: break-word;
}

.message-time {
  font-size: 0.75em;
  text-align: right;
  margin-top: 5px;
  color: #6c757d;
}

.message-input-container {
  display: flex;
  padding: 15px;
  border-top: 1px solid #dee2e6;
  background: white;
}

.message-input {
  flex-grow: 1;
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 20px;
  resize: none;
  height: 60px;
  font-family: inherit;
  font-size: 14px;
}

.send-button {
  background: #007bff;
  color: white;
  border: none;
  width: 45px;
  height: 45px;
  border-radius: 50%;
  margin-left: 10px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

.send-button:hover {
  background: #0056b3;
}

/* Responsive design */
@media (max-width: 768px) {
  .chat-container {
    height: 100vh;
    width: 100%;
    flex-direction: column;
  }
  
  .user-list {
    width: 100%;
    height: 30%;
    border-right: none;
    border-bottom: 1px solid #dee2e6;
  }
  
  .chat-room {
    height: 70%;
  }
}
