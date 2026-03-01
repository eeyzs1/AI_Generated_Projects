# 项目架构说明

## 目录结构

```
chat_app/
├── main.py
├── database.py
├── requirements.txt
├── Dockerfile
├── README.md
├── arch.md
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
└── frontend/
    ├── package.json
    ├── vite.config.ts
    ├── tsconfig.json
    ├── public/
    │   └── index.html
    └── src/
        ├── main.tsx
        ├── App.tsx
        ├── Login.tsx
        ├── Register.tsx
        ├── ChatRoom.tsx
        └── UserList.tsx
```

---

## 架构概览

```
浏览器 (React SPA)
    │
    ├── HTTP REST  ──►  FastAPI (main.py)
    │                       │
    └── WebSocket  ──►      ├── auth_service  ──► MySQL (users)
                            ├── chat_service  ──► MySQL (rooms, messages)
                            └── ws_service    ──► 内存连接池
```

- 前端通过 Vite dev server 代理，将 `/auth`、`/rooms`、`/users`、`/ws` 请求转发到后端 `localhost:8000`
- 生产环境下，FastAPI 直接 serve 前端 `dist/` 静态文件，单端口部署

---

## 后端文件说明

### `main.py`
FastAPI 应用入口。

- 注册 CORS 中间件
- `startup` 事件调用 `init_database()` 自动建表
- 定义所有 REST 路由：注册、登录、用户信息、聊天室 CRUD、消息
- 定义 WebSocket 端点 `/ws/rooms/{room_id}?token=...`：
  - 验证 JWT token
  - 接受连接，加入房间，推送历史消息
  - 循环接收消息，持久化后广播给房间内所有连接
  - 断开时清理连接，广播更新在线用户列表
- 生产模式下挂载前端静态文件，SPA fallback

---

### `database.py`
数据库连接与配置。

- `Settings`（pydantic-settings）：从 `.env` 读取 `MYSQL_*`、`JWT_SECRET_KEY` 等配置
- `get_settings()`：带 `@lru_cache` 的单例配置获取
- `engine`：SQLAlchemy MySQL 连接引擎，`pool_pre_ping=True`
- `SessionLocal`：数据库会话工厂
- `Base`：所有 ORM 模型的基类
- `get_db()`：FastAPI 依赖注入用的 session 生成器
- `init_database()`：导入所有模型后调用 `Base.metadata.create_all` 建表

---

## models/ — ORM 数据模型

### `models/user.py`
**User 表** + **room_members 关联表**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Integer PK | 主键 |
| username | String(50) unique | 用户名 |
| email | String(100) unique | 邮箱 |
| hashed_password | String(255) | bcrypt 加密密码 |
| created_at | DateTime | 注册时间 |

`room_members` 是 User ↔ Room 的多对多关联表，含 `joined_at` 字段。

---

### `models/room.py`
**Room 表**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Integer PK | 主键 |
| name | String(100) unique | 房间名 |
| creator_id | Integer FK(users.id) | 创建者 |
| created_at | DateTime | 创建时间 |

关系：`members`（多对多 User）、`messages`（一对多 Message）

---

### `models/message.py`
**Message 表**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Integer PK | 主键 |
| content | Text | 消息内容 |
| sender_id | Integer FK(users.id) | 发送者 |
| room_id | Integer FK(rooms.id) | 所属房间 |
| created_at | DateTime | 发送时间 |

---

### `models/__init__.py`
统一导入所有模型，确保 `init_database()` 能发现并建表。

---

## schemas/ — Pydantic 数据校验

### `schemas/user.py`
- `UserCreate`：注册请求体（username, email, password）
- `UserLogin`：登录请求体（username, password）
- `UserOut`：用户响应（id, username, email, created_at）
- `UserSummary`：精简用户信息（id, username），用于嵌套响应
- `Token`：登录响应（access_token, token_type）

### `schemas/room.py`
- `RoomCreate`：创建房间请求体（name）
- `RoomOut`：房间响应（含 members 列表）

### `schemas/message.py`
- `MessageCreate`：发送消息请求体（content）
- `MessageOut`：消息响应（含 sender 嵌套对象）

---

## services/ — 业务逻辑层

### `services/auth_service.py`
用户认证与授权。

- `get_password_hash` / `verify_password`：bcrypt 密码处理
- `create_access_token(user)`：生成 JWT，payload 含 `sub=user.id`
- `authenticate_user(db, username, password)`：验证用户名密码，失败抛 401
- `get_current_user_from_token(token, db)`：解码 JWT，查询并返回 User
- `get_current_user(...)`：FastAPI Depends 依赖，用于路由鉴权
- `create_user(db, ...)`：注册新用户，检查唯一性
- `get_db_session()`：为 WebSocket 提供原始 session（不走 Depends）

---

### `services/chat_service.py`
聊天室与消息业务逻辑。

- `create_room(db, data, user)`：创建房间，自动将创建者加入成员
- `get_room(db, room_id)`：查询房间（joinedload members），不存在抛 404
- `ensure_membership(room, user, db)`：若用户不在房间则自动加入
- `list_rooms(db)`：返回所有房间列表
- `create_message(db, room, user, data)`：校验成员身份，持久化消息
- `list_messages(db, room, limit=50)`：查询最近 50 条消息（joinedload sender）

---

### `services/ws_service.py`
WebSocket 连接管理（纯内存，单进程）。

`ConnectionManager` 维护：
- `room_connections`：房间 ID → WebSocket 集合
- `user_sessions`：用户 ID → 连接引用计数（支持同一用户多标签页）
- `usernames`：用户 ID → 用户名
- `websocket_user_map`：WebSocket → 用户 ID

方法：
- `add_connection`：注册新连接
- `remove_connection`：移除连接，引用计数归零时清除用户在线状态
- `broadcast_room`：向房间内所有连接广播 JSON
- `get_online_users`：返回当前在线用户列表

模块级单例 `manager` 供 `main.py` 使用。

---

## frontend/ — React 前端

### `frontend/package.json`
Vite + React + TypeScript 项目配置，定义 `dev` / `build` / `preview` 脚本。

### `frontend/vite.config.ts`
Vite 配置：启用 React 插件，dev server 代理 `/auth`、`/rooms`、`/users`、`/ws` 到后端。

### `frontend/tsconfig.json`
TypeScript 配置：target ES2020，jsx react-jsx，strict 模式。

### `frontend/public/index.html`
HTML 入口，挂载 `<div id="root">`，引入 `src/main.tsx`。

### `frontend/src/main.tsx`
React 应用入口，`ReactDOM.createRoot` 渲染 `<App />`。

### `frontend/src/App.tsx`
根组件，管理全局状态：
- `token`：JWT，存储于 `localStorage`
- `currentUser`：当前登录用户信息
- 根据登录状态路由到 `Login` / `Register` / `ChatRoom`
- 提供 `handleLogin`（存 token）和 `handleLogout`（清除 token）

### `frontend/src/Login.tsx`
登录表单组件：
- 表单字段：用户名、密码
- `POST /auth/login` 获取 token，再 `GET /users/me` 获取用户信息
- 登录成功回调父组件 `onLogin`
- 提供跳转注册页链接

### `frontend/src/Register.tsx`
注册表单组件：
- 表单字段：用户名、邮箱、密码
- `POST /auth/register` 注册成功后跳转登录页

### `frontend/src/ChatRoom.tsx`
核心聊天界面组件：
- 左侧边栏：房间列表、创建房间输入框、在线用户列表
- 右侧主区：消息列表、消息输入框
- WebSocket 管理：连接 `/ws/rooms/{id}?token=...`，处理 `history` / `message` / `users` 三类事件
- 加入房间时调用 `POST /rooms/{id}/join`

### `frontend/src/UserList.tsx`
在线用户列表展示组件，接收 `users` prop，渲染带绿点的用户名列表。

---

## 基础设施

### `Dockerfile`
多阶段构建：
1. `node:20-alpine`：构建前端，输出 `dist/`
2. `python:3.11-slim`：安装 Python 依赖，复制后端代码和前端 `dist/`，启动 uvicorn

### `requirements.txt`
后端 Python 依赖清单（见 README.md）。
