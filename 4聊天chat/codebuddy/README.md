# Chat App - 实时聊天应用

> 一个基于 FastAPI 和 React 的现代化实时聊天应用，支持多用户、多聊天室的即时通讯功能

![FastAPI](https://img.shields.io/badge/FastAPI-0.104.1-green)
![React](https://img.shields.io/badge/React-18-blue)
![TypeScript](https://img.shields.io/badge/TypeScript-5.3-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 📋 功能特性

### 核心功能
- ✅ **用户认证系统** - 用户注册、登录，基于JWT的身份验证
- ✅ **聊天室管理** - 创建聊天室、邀请成员、查看聊天室详情
- ✅ **实时消息** - 基于WebSocket的实时消息发送和接收
- ✅ **在线状态** - 实时显示用户在线/离线状态
- ✅ **用户列表** - 浏览所有注册用户及其状态
- ✅ **响应式设计** - 美观且适配不同屏幕的现代化UI

### 技术亮点
- 🔐 密码使用bcrypt加密存储
- 🔑 JWT Token认证机制
- 🔄 WebSocket自动重连
- 📊 SQLAlchemy ORM数据库操作
- 🐳 Docker容器化部署支持

## 🛠 技术栈

### 后端
| 技术 | 版本 | 用途 |
|------|------|------|
| FastAPI | 0.104.1 | Web框架 |
| SQLAlchemy | 2.0.23 | ORM工具 |
| PyMySQL | 1.1.0 | MySQL驱动 |
| python-jose | 3.3.0 | JWT处理 |
| passlib | 1.7.4 | 密码加密 |
| WebSocket | 12.0 | 实时通信 |

### 前端
| 技术 | 版本 | 用途 |
|------|------|------|
| React | 18.2.0 | UI框架 |
| TypeScript | 5.3.3 | 类型安全 |
| React Router | 6.20.0 | 路由管理 |
| Axios | 1.6.2 | HTTP客户端 |
| Vite | 5.0.8 | 构建工具 |

### 数据库
- MySQL 8.0+

## 📁 项目结构

```
chat_app/
├── main.py                 # FastAPI主应用入口
├── database.py             # 数据库连接配置
├── requirements.txt        # Python依赖包
├── Dockerfile             # Docker容器化配置
├── .gitignore             # Git忽略文件配置
├── README.md              # 项目说明文档
├── arch.md                # 架构详细文档
│
├── models/                # 数据模型层
│   ├── __init__.py       # 模型导出
│   ├── user.py           # 用户模型
│   ├── room.py           # 聊天室模型
│   └── message.py        # 消息模型
│
├── schemas/              # Pydantic数据验证模式
│   ├── __init__.py      # 模式导出
│   ├── user.py          # 用户相关模式
│   ├── room.py          # 聊天室相关模式
│   └── message.py       # 消息相关模式
│
├── services/            # 业务逻辑层
│   ├── __init__.py     # 服务导出
│   ├── auth_service.py # 认证服务
│   ├── chat_service.py # 聊天服务
│   └── ws_service.py   # WebSocket服务
│
└── frontend/           # React前端应用
    ├── package.json   # Node.js依赖
    ├── vite.config.ts # Vite构建配置
    ├── tsconfig.json  # TypeScript配置
    ├── tsconfig.node.json
    │
    ├── public/
    │   └── index.html # HTML入口
    │
    └── src/
        ├── App.tsx                # 主应用组件
        ├── main.tsx              # React入口
        ├── Login.tsx             # 登录页面
        ├── Register.tsx          # 注册页面
        ├── ChatRoom.tsx          # 聊天室主界面
        ├── UserList.tsx          # 用户列表组件
        ├── api.ts                # API调用封装
        ├── types.ts              # TypeScript类型定义
        └── WebSocketContext.tsx  # WebSocket上下文
```

## 🚀 快速开始

### 前置要求

在运行项目之前，请确保已安装以下软件：

- **Python** 3.11 或更高版本
- **Node.js** 18 或更高版本
- **MySQL** 8.0 或更高版本
- **Git**（可选，用于克隆代码）

### 1. 克隆项目

```bash
git clone <your-repo-url>
cd chat_app
```

### 2. 数据库设置

#### 创建MySQL数据库

登录到MySQL并创建数据库：

```sql
-- 登录MySQL
mysql -u root -p

-- 创建数据库
CREATE DATABASE chat_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 退出
EXIT;
```

#### 配置数据库连接

编辑 `database.py` 文件，修改数据库连接信息：

```python
# 修改为你的MySQL配置
DATABASE_URL = "mysql+pymysql://root:your_password@localhost:3306/chat_app?charset=utf8mb4"
```

### 3. 后端启动

#### 安装Python依赖

```bash
pip install -r requirements.txt
```

如果安装速度较慢，可以使用国内镜像源：

```bash
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

#### 启动FastAPI应用

使用Python直接运行：

```bash
python main.py
```

或使用uvicorn启动（推荐开发环境使用）：

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

启动成功后，访问以下地址查看API文档：
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

### 4. 前端启动

#### 安装Node.js依赖

```bash
cd frontend
npm install
```

如果安装速度较慢，可以使用淘宝镜像：

```bash
npm install --registry=https://registry.npmmirror.com
```

#### 启动开发服务器

```bash
npm run dev
```

启动成功后，访问前端应用：
- **应用地址**: http://localhost:3000

### 5. 开始使用

1. 打开浏览器访问 http://localhost:3000
2. 点击"注册"创建新账户
3. 使用用户名和密码登录
4. 点击"+"号创建新的聊天室
5. 从右侧用户列表邀请其他用户加入聊天室
6. 开始发送和接收消息！

## 🐳 Docker部署

### 构建Docker镜像

```bash
docker build -t chat-app .
```

### 运行容器

```bash
docker run -d -p 8000:8000 --name chat-app chat-app
```

### 查看日志

```bash
docker logs -f chat-app
```

### 停止和删除容器

```bash
docker stop chat-app
docker rm chat-app
```

### Docker Compose部署（可选）

创建 `docker-compose.yml` 文件：

```yaml
version: '3.8'

services:
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: chat_app
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

  app:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - db
    environment:
      DATABASE_URL: mysql+pymysql://root:rootpassword@db:3306/chat_app

volumes:
  mysql_data:
```

运行：

```bash
docker-compose up -d
```

## 📡 API端点

### 认证接口

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | `/api/auth/register` | 用户注册 |
| POST | `/api/auth/login` | 用户登录，返回JWT Token |
| GET | `/api/auth/me` | 获取当前用户信息 |

### 用户接口

| 方法 | 端点 | 描述 |
|------|------|------|
| GET | `/api/users` | 获取所有用户列表 |

### 聊天室接口

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | `/api/rooms` | 创建聊天室 |
| GET | `/api/rooms` | 获取当前用户所在的所有聊天室 |
| GET | `/api/rooms/{room_id}` | 获取聊天室详情（包含成员列表） |
| POST | `/api/rooms/members` | 添加成员到聊天室 |

### 消息接口

| 方法 | 端点 | 描述 |
|------|------|------|
| GET | `/api/rooms/{room_id}/messages` | 获取聊天室的历史消息 |

### WebSocket接口

| 连接 | 描述 |
|------|------|
| `WS /ws/{token}` | WebSocket实时通信端点 |

#### WebSocket消息格式

**发送消息**:
```json
{
  "type": "message",
  "room_id": 1,
  "content": "Hello World!"
}
```

**接收消息**:
```json
{
  "type": "message",
  "data": {
    "id": 1,
    "room_id": 1,
    "sender_id": 1,
    "sender_username": "user1",
    "content": "Hello World!",
    "created_at": "2024-01-01T12:00:00"
  }
}
```

**在线用户更新**:
```json
{
  "type": "online_users",
  "data": {
    "user_ids": [1, 2, 3]
  }
}
```

## 🗄️ 数据库设计

### 用户表 (users)

| 字段 | 类型 | 说明 | 约束 |
|------|------|------|------|
| id | INT | 用户ID | PRIMARY KEY |
| username | VARCHAR(50) | 用户名 | UNIQUE, NOT NULL |
| email | VARCHAR(100) | 邮箱 | UNIQUE, NOT NULL |
| hashed_password | VARCHAR(255) | 加密密码 | NOT NULL |
| created_at | DATETIME | 创建时间 | DEFAULT CURRENT_TIMESTAMP |
| is_online | INT | 在线状态(0/1) | DEFAULT 0 |

### 聊天室表 (rooms)

| 字段 | 类型 | 说明 | 约束 |
|------|------|------|------|
| id | INT | 聊天室ID | PRIMARY KEY |
| name | VARCHAR(100) | 聊天室名称 | NOT NULL |
| creator_id | INT | 创建者ID | FOREIGN KEY(users.id) |
| created_at | DATETIME | 创建时间 | DEFAULT CURRENT_TIMESTAMP |

### 聊天室成员表 (room_members)

| 字段 | 类型 | 说明 | 约束 |
|------|------|------|------|
| id | INT | 记录ID | PRIMARY KEY |
| room_id | INT | 聊天室ID | FOREIGN KEY(rooms.id) |
| user_id | INT | 用户ID | FOREIGN KEY(users.id) |
| joined_at | DATETIME | 加入时间 | DEFAULT CURRENT_TIMESTAMP |

### 消息表 (messages)

| 字段 | 类型 | 说明 | 约束 |
|------|------|------|------|
| id | INT | 消息ID | PRIMARY KEY |
| room_id | INT | 聊天室ID | FOREIGN KEY(rooms.id) |
| sender_id | INT | 发送者ID | FOREIGN KEY(users.id) |
| content | TEXT | 消息内容 | NOT NULL |
| created_at | DATETIME | 发送时间 | DEFAULT CURRENT_TIMESTAMP |

## 📝 详细文档

更多详细的架构设计和实现说明，请参考 [arch.md](./arch.md) 文档。

## 🔧 开发指南

### 添加新功能

1. **后端**:
   - 在 `models/` 中添加数据模型
   - 在 `schemas/` 中添加数据验证模式
   - 在 `services/` 中添加业务逻辑
   - 在 `main.py` 中添加API路由

2. **前端**:
   - 在 `src/` 中添加新组件
   - 在 `api.ts` 中添加API调用
   - 在 `types.ts` 中添加类型定义

### 调试技巧

- 后端：访问 http://localhost:8000/docs 查看和测试API
- 前端：使用浏览器开发者工具查看网络请求和控制台日志
- WebSocket：使用浏览器控制台的Network > WS选项卡查看WebSocket消息

## ⚠️ 注意事项

### 生产环境配置

1. **修改JWT密钥**:
   ```python
   # 在 main.py 中修改
   SECRET_KEY = "your-super-secret-key-change-in-production"
   ```

2. **使用HTTPS**:
   - 配置反向代理（如Nginx）
   - 启用SSL证书（Let's Encrypt）

3. **CORS配置**:
   ```python
   # 修改为特定域名
   app.add_middleware(
       CORSMiddleware,
       allow_origins=["https://yourdomain.com"],
       allow_credentials=True,
       allow_methods=["*"],
       allow_headers=["*"],
   )
   ```

4. **数据库安全**:
   - 使用强密码
   - 限制数据库远程访问
   - 定期备份数据

5. **环境变量**:
   - 建议使用 `.env` 文件存储敏感信息
   - 不要将密钥提交到版本控制

### 性能优化

- 启用数据库连接池（已配置）
- 使用Redis缓存会话（可选）
- 启用Gzip压缩（前端构建时）
- 使用CDN加速静态资源（可选）

## 🐛 常见问题

### Q: 连接数据库失败？
A: 检查MySQL服务是否启动，数据库连接信息是否正确。

### Q: 前端无法连接后端？
A: 检查后端是否在8000端口运行，查看 `vite.config.ts` 中的代理配置。

### Q: WebSocket连接失败？
A: 检查JWT Token是否有效，确认WebSocket端点地址正确。

### Q: 消息无法实时接收？
A: 检查浏览器控制台是否有错误，确认WebSocket连接状态。

## 📄 License

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**⭐ 如果这个项目对你有帮助，请给个 Star！**
