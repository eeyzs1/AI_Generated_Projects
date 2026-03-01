import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from main import app
from services import auth_service

# Configure an in-memory SQLite DB shared across threads for the TestClient.
engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
auth_service.SessionLocal = TestingSessionLocal
client = TestClient(app)


@pytest.fixture(autouse=True)
def _reset_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)


def register_user(username: str, email: str, password: str) -> None:
    response = client.post(
        "/auth/register",
        json={"username": username, "email": email, "password": password},
    )
    assert response.status_code == 201, response.text


def login(username: str, password: str) -> str:
    response = client.post("/auth/login", json={"username": username, "password": password})
    assert response.status_code == 200, response.text
    token = response.json()["access_token"]
    return token


def auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_full_chat_flow():
    register_user("alice", "alice@example.com", "secret123")
    token = login("alice", "secret123")

    room_response = client.post(
        "/rooms",
        headers=auth_header(token),
        json={"name": "general"},
    )
    assert room_response.status_code == 201
    room_id = room_response.json()["id"]

    rooms = client.get("/rooms", headers=auth_header(token))
    assert rooms.status_code == 200
    assert any(room["id"] == room_id for room in rooms.json())

    message_response = client.post(
        f"/rooms/{room_id}/messages",
        headers=auth_header(token),
        json={"content": "Hello everyone"},
    )
    assert message_response.status_code == 201
    message_body = message_response.json()
    assert message_body["content"] == "Hello everyone"

    history = client.get(f"/rooms/{room_id}/messages", headers=auth_header(token))
    assert history.status_code == 200
    messages = history.json()
    assert len(messages) == 1
    assert messages[0]["content"] == "Hello everyone"


def test_duplicate_username_rejected():
    register_user("bob", "bob@example.com", "pass1234")
    response = client.post(
        "/auth/register",
        json={"username": "bob", "email": "bob2@example.com", "password": "pass1234"},
    )
    assert response.status_code == 400
    assert "exists" in response.json()["detail"].lower()
