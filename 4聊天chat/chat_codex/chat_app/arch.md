# Architecture Overview

## Backend (chat_app)
- `main.py`: FastAPI application wiring REST auth endpoints, room/message APIs, startup DB init, SPA serving, and `/ws/rooms/{room_id}` WebSocket for live chat + online user updates.
- `database.py`: Central config + SQLAlchemy engine/session factory; reads MySQL + JWT settings via `Settings`, exposes `get_db` dependency and `init_database` helper.
- `requirements.txt`: Pinned backend runtime deps (FastAPI, SQLAlchemy, MySQL driver, JWT, bcrypt, dotenv, etc.).
- `Dockerfile`: Multi-stage build (Node 20 for Vite frontend, Python 3.12 slim for backend) producing a single image that serves API + built static assets via Uvicorn.
- `__init__.py`: Marks package for relative imports.

### Models (`models/`)
- `user.py`: SQLAlchemy `User` entity + `room_members` association table storing credentials, timestamps, relationships to rooms/messages.
- `room.py`: `Room` entity with creator link, timestamp, and many-to-many membership/backrefs.
- `message.py`: `Message` entity linking sender + room with timestamped text payload.
- `__init__.py`: Convenience re-exports to ensure metadata registration.

### Schemas (`schemas/`)
- `user.py`: Pydantic models for registration/login payloads, JWT tokens, and safe user outputs.
- `room.py`: Pydantic room DTOs (create + response) with member summaries.
- `message.py`: Message create/response DTOs referencing sender summaries.
- `__init__.py`: Package marker.

### Services (`services/`)
- `auth_service.py`: Password hashing, JWT issuing/verification, OAuth dependency, helper to create/authenticate users, and raw DB session for WebSocket use.
- `chat_service.py`: Room creation/listing/membership enforcement and message CRUD/history helpers with joined loading.
- `ws_service.py`: `ConnectionManager` for WebSocket lifecycle, broadcasting, and online user tracking; exported singleton `manager`.
- `__init__.py`: Package marker.

## Frontend (`frontend/`)
- `package.json`: React + Vite + TypeScript dependencies/scripts.
- `tsconfig.json`: TS compiler settings for Vite.
- `vite.config.ts`: Vite + React plugin config (port 5173 dev server).
- `public/index.html`: HTML shell that loads `src/main.tsx`.
- `src/main.tsx`: React bootstrap + global styles import.
- `src/styles.css`: Base responsive styles shared across components.
- `src/types.ts`: Shared TS interfaces mirroring backend DTOs.
- `src/App.tsx`: Root SPA; handles auth, room selection/creation, REST calls via axios, and state wiring for WebSocket handlers.
- `src/Login.tsx` / `src/Register.tsx`: Controlled auth forms.
- `src/UserList.tsx`: Online user sidebar.
- `src/ChatRoom.tsx`: Room view managing WebSocket connection, history playback, message compose/send, and online user updates.
- `src/vite-env.d.ts`: Vite TypeScript ambient types.

## Generated/Bundled Assets
- `frontend/dist/` (created after `npm run build`): served via FastAPI when present, mounted on `/assets`.

## Runtime Flow
1. Users register/login via REST; FastAPI returns JWT tokens.
2. Authenticated clients call room/message REST endpoints and open `ws://.../ws/rooms/{room_id}?token=JWT` to stream/broadcast messages in real-time.
3. `ConnectionManager` tracks sockets + users to push both message history and online user lists.
4. React SPA persists tokens in `localStorage`, fetches initial data, and keeps UI synced through WebSocket events.
