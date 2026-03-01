"""Tests for authentication endpoints: register and login."""
import pytest
from helpers import register_and_login, auth_headers


class TestRegister:
    def test_register_success(self, client):
        resp = client.post("/auth/register", json={
            "username": "alice",
            "email": "alice@example.com",
            "password": "secret123"
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["username"] == "alice"
        assert data["email"] == "alice@example.com"
        assert "id" in data
        assert "hashed_password" not in data

    def test_register_duplicate_username(self, client):
        client.post("/auth/register", json={"username": "bob", "email": "bob@example.com", "password": "pass"})
        resp = client.post("/auth/register", json={"username": "bob", "email": "bob2@example.com", "password": "pass"})
        assert resp.status_code == 400
        assert "Username already registered" in resp.json()["detail"]

    def test_register_duplicate_email(self, client):
        client.post("/auth/register", json={"username": "carol", "email": "shared@example.com", "password": "pass"})
        resp = client.post("/auth/register", json={"username": "carol2", "email": "shared@example.com", "password": "pass"})
        assert resp.status_code == 400
        assert "Email already registered" in resp.json()["detail"]

    def test_register_invalid_email(self, client):
        resp = client.post("/auth/register", json={
            "username": "dave",
            "email": "not-an-email",
            "password": "pass"
        })
        assert resp.status_code == 422


class TestLogin:
    def test_login_success(self, client):
        client.post("/auth/register", json={"username": "eve", "email": "eve@example.com", "password": "mypass"})
        resp = client.post("/auth/login", json={"username": "eve", "password": "mypass"})
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    def test_login_wrong_password(self, client):
        client.post("/auth/register", json={"username": "frank", "email": "frank@example.com", "password": "correct"})
        resp = client.post("/auth/login", json={"username": "frank", "password": "wrong"})
        assert resp.status_code == 401

    def test_login_nonexistent_user(self, client):
        resp = client.post("/auth/login", json={"username": "ghost", "password": "pass"})
        assert resp.status_code == 401

    def test_get_me(self, client):
        token = register_and_login(client, "grace")
        resp = client.get("/users/me", headers=auth_headers(token))
        assert resp.status_code == 200
        assert resp.json()["username"] == "grace"

    def test_get_me_no_token(self, client):
        resp = client.get("/users/me")
        assert resp.status_code == 401

    def test_get_me_invalid_token(self, client):
        resp = client.get("/users/me", headers={"Authorization": "Bearer invalid.token.here"})
        assert resp.status_code == 401
