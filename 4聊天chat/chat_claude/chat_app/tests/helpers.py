"""Shared test helper functions."""
from fastapi.testclient import TestClient


def register_and_login(client: TestClient, username: str, password: str = "pass1234", email: str = None) -> str:
    if email is None:
        email = f"{username}@example.com"
    client.post("/auth/register", json={"username": username, "email": email, "password": password})
    resp = client.post("/auth/login", json={"username": username, "password": password})
    return resp.json()["access_token"]


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}
