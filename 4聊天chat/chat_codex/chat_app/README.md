# Chat Codex

A full-stack demo that pairs a FastAPI + SQLAlchemy backend with a React (Vite + TypeScript) frontend to deliver a lightweight WeChat-style chat experience featuring JWT auth, MySQL persistence, and WebSocket-powered real-time messaging/online user presence.

## Features
- User registration/login with hashed passwords and JWT-based sessions.
- Room creation, membership enforcement, and message history storage in MySQL.
- Live messaging + online user roster over WebSockets.
- Responsive React SPA with axios-powered REST calls and WS integration.
- Dockerfile for turnkey container builds serving API + static assets.

## Tech Stack
- **Backend:** Python 3.12, FastAPI, SQLAlchemy 2.x, MySQL Connector, passlib, python-jose.
- **Frontend:** React 18, TypeScript, Vite, Axios.
- **Auth:** OAuth2 password flow, JWT tokens.
- **Realtime:** Native WebSocket endpoint per room.
- **Packaging:** Docker multi-stage build (Node 20 + python:3.12-slim).

## Prerequisites
- Python 3.12+
- Node.js 20+ and npm
- MySQL 8+ (or compatible server)
- (Optional) Docker 24+

## Configuration
Create `chat_app/.env` (same directory as `main.py`) to override defaults:
```
MYSQL_USER=chat_user
MYSQL_PASSWORD=chat_password
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DB=chat_app
JWT_SECRET_KEY=replace_me
ACCESS_TOKEN_EXPIRE_MINUTES=60
CORS_ALLOW_ORIGINS=http://localhost:5173
```
Match these credentials with an existing MySQL database/user.

For the frontend, create `chat_app/frontend/.env` if you need a non-default API base:
```
VITE_API_BASE_URL=http://localhost:8000
```

## Backend Setup & Run
```
cd chat_app
python -m venv .venv
.\.venv\Scripts\activate      # Windows PowerShell
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
The API serves swagger docs at `http://localhost:8000/docs` and (after building the frontend) static assets on `/`.

## Frontend Setup & Run (Dev)
```
cd chat_app/frontend
npm install
npm run dev -- --host 0.0.0.0 --port 5173
```
The dev server proxies API calls directly to the backend URL set in `VITE_API_BASE_URL` (defaults to `http://localhost:8000`).

## Build Frontend for Production
```
cd chat_app/frontend
npm install        # once
npm run build
```
This outputs `frontend/dist`, which the FastAPI app will serve automatically when present.

## Docker Workflow
```
cd chat_app
docker build -t chat-codex .
docker run --rm -p 8000:8000 --env-file .env chat-codex
```
Ensure the container can reach your MySQL instance (publish ports or run within the same network). The built image already contains the compiled frontend, so you only need to run the container.

## Useful Commands
- `uvicorn main:app --reload`: start backend with hot reload.
- `npm run dev`: run Vite dev server with React Fast Refresh.
- `npm run build && uvicorn main:app`: rebuild SPA + serve via FastAPI.
- `docker compose up` (if you later add a compose file) to orchestrate DB + app.

## Testing & Verification
- `python -m compileall .`: quick syntax validation for backend modules.
- Add Playwright/Cypress or React Testing Library suites as desired for the frontend.

Happy chatting!
