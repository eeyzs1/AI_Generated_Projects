"""
Shared fixtures for all tests.
Uses SQLite in-memory — no MySQL required.

The challenge: database.py creates engine + SessionLocal at module level.
Solution: patch them before any model/app import, using StaticPool so all
connections share the same in-memory SQLite instance.
"""
import os
import sys
import pytest

os.environ["MYSQL_USER"] = "test"
os.environ["MYSQL_PASSWORD"] = "test"
os.environ["MYSQL_HOST"] = "localhost"
os.environ["MYSQL_DB"] = "testdb"
os.environ["JWT_SECRET_KEY"] = "test-secret-key"

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Build SQLite engine with StaticPool — all connections share one in-memory DB
test_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

# Patch database module BEFORE importing models or app
import database
database.engine = test_engine
database.SessionLocal = TestingSessionLocal

# Now import models (registers tables on Base.metadata) and create them
from database import Base, get_db
import models  # noqa: registers User, Room, Message, room_members
Base.metadata.create_all(bind=test_engine)

# Safe to import app now
from main import app  # noqa
from fastapi.testclient import TestClient


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def clean_tables():
    """Delete all rows between tests."""
    yield
    db = TestingSessionLocal()
    try:
        from models.user import room_members
        from models.message import Message
        from models.room import Room
        from models.user import User
        db.execute(room_members.delete())
        db.query(Message).delete()
        db.query(Room).delete()
        db.query(User).delete()
        db.commit()
    finally:
        db.close()


@pytest.fixture
def client():
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def db():
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
