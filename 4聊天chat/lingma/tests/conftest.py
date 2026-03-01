import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from database import Base
from models.user import User
from models.room import Room
from models.message import Message
from services.auth_service import get_password_hash

# Test database configuration
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="session")
def test_db():
    """Create test database tables"""
    Base.metadata.create_all(bind=engine)
    try:
        yield TestingSessionLocal()
    finally:
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def db_session(test_db):
    """Create a clean database session for each test"""
    test_db.begin_nested()
    yield test_db
    test_db.rollback()

@pytest.fixture(scope="function")
def client():
    """Create a test client for the FastAPI app"""
    def override_get_db():
        try:
            db = TestingSessionLocal()
            yield db
        finally:
            db.close()
    
    app.dependency_overrides[lambda: next(override_get_db())] = lambda: next(override_get_db())
    
    with TestClient(app) as c:
        yield c
    
    app.dependency_overrides.clear()

@pytest.fixture
def test_user(db_session):
    """Create a test user"""
    user = User(
        username="testuser",
        email="test@example.com",
        hashed_password=get_password_hash("testpassword"),
        is_active=True,
        is_online=False
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture
def test_user2(db_session):
    """Create a second test user"""
    user = User(
        username="testuser2",
        email="test2@example.com",
        hashed_password=get_password_hash("testpassword2"),
        is_active=True,
        is_online=False
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture
def authenticated_client(client, test_user):
    """Create an authenticated test client"""
    # First login to get token
    response = client.post("/login", json={
        "username": "testuser",
        "password": "testpassword"
    })
    assert response.status_code == 200
    token = response.json()["access_token"]
    
    # Create new client with authentication header
    client.headers = {"Authorization": f"Bearer {token}"}
    return client

@pytest.fixture
def test_room(db_session, test_user):
    """Create a test room"""
    room = Room(
        name="Test Room",
        creator_id=test_user.id
    )
    db_session.add(room)
    db_session.commit()
    db_session.refresh(room)
    
    # Add creator as member
    room.members.append(test_user)
    db_session.commit()
    return room

@pytest.fixture
def mock_websocket():
    """Create a mock WebSocket connection"""
    mock_ws = Mock()
    mock_ws.accept = Mock()
    mock_ws.send_text = Mock()
    mock_ws.receive_text = Mock()
    mock_ws.close = Mock()
    return mock_ws