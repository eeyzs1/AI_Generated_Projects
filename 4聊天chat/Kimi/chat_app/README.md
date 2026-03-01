# Chat App - 类似微信的聊天应用

这是一个使用FastAPI和React构建的即时通讯应用，具有类似微信的基本功能。

## 功能特性

- ✅ 用户注册和登录系统（JWT认证）
- ✅ 聊天室创建和管理
- ✅ 实时消息发送和接收（WebSocket）
- ✅ 在线用户列表实时更新
- ✅ 消息历史记录
- ✅ 响应式前端界面

## 技术栈

### 后端
- **FastAPI** - Web框架
- **SQLAlchemy** - ORM
- **MySQL** - 数据库
- **WebSocket** - 实时通信
- **JWT** - 身份认证
- **Passlib** - 密码加密

### 前端
- **React 18** - UI框架
- **TypeScript** - 类型安全
- **Vite** - 构建工具
- **Axios** - HTTP客户端
- **React Router** - 路由管理

## 项目结构

```
chat_app/
├── main.py                 # FastAPI应用入口
├── database.py             # 数据库配置
├── requirements.txt        # Python依赖
├── Dockerfile              # Docker配置
├── docker-compose.yml      # Docker Compose配置
├── models/                 # 数据模型
│   ├── user.py
│   ├── room.py
│   └── message.py
├── schemas/                # Pydantic模型
│   ├── user.py
│   ├── room.py
│   └── message.py
├── services/               # 业务逻辑
│   ├── auth_service.py
│   ├── chat_service.py
│   └── ws_service.py
└── frontend/               # React前端
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

## 快速开始

### 方法一：使用Docker Compose（推荐）

1. 确保已安装Docker和Docker Compose

2. 克隆项目并进入目录：
```bash
cd chat_app
```

3. 启动服务：
```bash
docker-compose up -d
```

4. 等待数据库初始化完成，然后访问：
- 后端API: http://localhost:8000
- API文档: http://localhost:8000/docs

### 方法二：本地开发环境

#### 后端设置

1. 创建Python虚拟环境：
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

2. 安装依赖：
```bash
pip install -r requirements.txt
```

3. 配置MySQL数据库：
- 安装MySQL并创建数据库 `chat_app`
- 修改 `database.py` 中的数据库连接配置

4. 启动后端服务：
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

#### 前端设置

1. 进入前端目录：
```bash
cd frontend
```

2. 安装依赖：
```bash
npm install
```

3. 启动开发服务器：
```bash
npm run dev
```

4. 访问 http://localhost:3000

## API接口

### 认证接口
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `POST /api/auth/logout` - 用户登出
- `GET /api/auth/me` - 获取当前用户信息

### 用户接口
- `GET /api/users` - 获取所有用户
- `GET /api/users/online` - 获取在线用户

### 聊天室接口
- `POST /api/rooms` - 创建聊天室
- `GET /api/rooms` - 获取我的聊天室列表
- `GET /api/rooms/{room_id}` - 获取聊天室详情
- `POST /api/rooms/{room_id}/join` - 加入聊天室
- `POST /api/rooms/{room_id}/leave` - 离开聊天室

### 消息接口
- `GET /api/rooms/{room_id}/messages` - 获取消息历史
- `POST /api/rooms/{room_id}/messages` - 发送消息

### WebSocket
- `WS /ws/{token}` - WebSocket连接

## WebSocket消息格式

```json
// 发送消息
{
  "type": "message",
  "data": {
    "room_id": 1,
    "content": "你好！",
    "message_type": "text"
  }
}

// 加入房间
{
  "type": "join_room",
  "data": {
    "room_id": 1
  }
}

// 离开房间
{
  "type": "leave_room",
  "data": {
    "room_id": 1
  }
}

// 正在输入
{
  "type": "typing",
  "data": {
    "room_id": 1
  }
}
```

## 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| DB_HOST | 数据库主机 | localhost |
| DB_PORT | 数据库端口 | 3306 |
| DB_USER | 数据库用户 | root |
| DB_PASSWORD | 数据库密码 | password |
| DB_NAME | 数据库名称 | chat_app |
| SECRET_KEY | JWT密钥 | your-secret-key-here |

## 生产部署

1. 修改 `SECRET_KEY` 为强密码
2. 使用HTTPS
3. 配置数据库连接池
4. 使用反向代理（如Nginx）
5. 配置日志和监控

## 许可证

MIT License
