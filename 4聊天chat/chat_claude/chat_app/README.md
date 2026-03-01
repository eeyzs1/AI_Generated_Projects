# Chat App

基于 FastAPI + React + WebSocket 构建的类微信实时聊天应用。

## 功能特性

- 用户注册与登录（JWT 认证）
- 创建 / 加入聊天室
- 实时消息收发（WebSocket）
- 在线用户列表实时更新
- Docker 容器化部署支持

---

## 技术栈

| 层 | 技术 |
|---|---|
| 后端框架 | FastAPI |
| 数据库 ORM | SQLAlchemy |
| 数据库 | MySQL 8.0 |
| 认证 | JWT (python-jose) |
| 密码加密 | bcrypt (passlib) |
| 前端框架 | React 18 + TypeScript |
| 前端构建 | Vite |
| 实时通信 | WebSocket |
| 容器化 | Docker |

---

## 项目依赖

### 后端（Python 3.11+）

| 包 | 用途 |
|---|---|
| fastapi | Web 框架 |
| uvicorn[standard] | ASGI 服务器 |
| sqlalchemy | ORM |
| mysql-connector-python | MySQL 驱动 |
| python-jose[cryptography] | JWT 生成与验证 |
| passlib[bcrypt] | 密码加密 |
| pydantic[email] | 数据校验（含邮箱验证） |
| pydantic-settings | 从 .env 读取配置 |
| python-multipart | 表单数据支持 |

### 前端（Node.js 20+）

| 包 | 用途 |
|---|---|
| react / react-dom | UI 框架 |
| vite | 构建工具 |
| @vitejs/plugin-react | Vite React 插件 |
| typescript | 类型系统 |

---

## 环境配置

在 `chat_app/` 目录下创建 `.env` 文件：

```env
MYSQL_USER=root
MYSQL_PASSWORD=your_password
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_DB=chatapp
JWT_SECRET_KEY=change-this-to-a-long-random-secret
ACCESS_TOKEN_EXPIRE_MINUTES=1440
CORS_ALLOW_ORIGINS=http://localhost:5173,http://localhost:3000
```

---

## 运行方式

### 方式一：Docker Compose（推荐，自带 MySQL）

在 `chat_app/` 目录下创建 `docker-compose.yml`：

```yaml
version: "3.9"
services:
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: chatapp
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      retries: 10

  app:
    build: .
    ports:
      - "8000:8000"
    env_file: .env
    environment:
      MYSQL_HOST: db
    depends_on:
      db:
        condition: service_healthy
```

启动：

```bash
cd chat_app
docker-compose up --build
```

访问：http://localhost:8000

---

### 方式二：本地开发

**前提条件：** Python 3.11+、Node.js 20+、MySQL 8.0+

#### 1. 准备数据库

```sql
CREATE DATABASE chatapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

#### 2. 安装后端依赖

```bash
cd chat_app

# 创建并激活虚拟环境
python -m venv venv
# Windows:
venv\Scripts\activate
# macOS / Linux:
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

#### 3. 启动后端

```bash
uvicorn main:app --reload --port 8000
```

- 后端地址：http://localhost:8000
- API 文档：http://localhost:8000/docs
- 数据库表会在首次启动时自动创建

#### 4. 安装前端依赖并启动（新开终端）

```bash
cd chat_app/frontend
npm install
npm run dev
```

前端地址：http://localhost:5173

> 前端 dev server 已配置代理，`/auth`、`/rooms`、`/users`、`/ws` 请求自动转发到后端 8000 端口。

---

## API 概览

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /auth/register | 注册新用户 |
| POST | /auth/login | 登录，返回 JWT token |
| GET | /users/me | 获取当前用户信息 |
| GET | /users/online | 获取在线用户列表 |
| POST | /rooms | 创建聊天室 |
| GET | /rooms | 获取聊天室列表 |
| POST | /rooms/{id}/join | 加入聊天室 |
| GET | /rooms/{id}/messages | 获取历史消息 |
| WS | /ws/rooms/{id}?token=... | WebSocket 实时通信 |
| GET | /health | 健康检查 |

---

## WebSocket 消息格式

服务端推送：

```json
{ "type": "history", "messages": [...] }
{ "type": "users", "users": [{"id": 1, "username": "alice"}] }
{ "type": "message", "id": 1, "content": "hello", "sender": {...}, "room_id": 1, "created_at": "..." }
```

客户端发送：

```json
{ "content": "消息内容" }
```

---

## 注意事项

- `JWT_SECRET_KEY` 生产环境务必替换为随机长字符串
- WebSocket 连接管理为单进程内存实现，多进程部署需引入 Redis Pub/Sub
- 详细架构说明见 [arch.md](arch.md)
