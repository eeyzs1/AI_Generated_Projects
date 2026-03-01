# Chat App 项目架构文档

## 项目概述

这是一个基于 FastAPI 和 React 的实时聊天应用，支持用户注册登录、聊天室管理、实时消息传递和在线用户管理。

## 项目结构

```
chat_app/
├── main.py                 # FastAPI主应用入口
├── database.py             # 数据库连接配置
├── requirements.txt        # Python依赖包
├── Dockerfile             # Docker容器化配置
├── .gitignore             # Git忽略文件配置
├── models/                # 数据模型层
│   ├── __init__.py       # 模型导出
│   ├── user.py           # 用户模型
│   ├── room.py           # 聊天室模型
│   └── message.py        # 消息模型
├── schemas/              # Pydantic数据验证模式
│   ├── __init__.py      # 模式导出
│   ├── user.py          # 用户相关模式
│   ├── room.py          # 聊天室相关模式
│   └── message.py       # 消息相关模式
├── services/            # 业务逻辑层
│   ├── __init__.py     # 服务导出
│   ├── auth_service.py # 认证服务
│   ├── chat_service.py # 聊天服务
│   └── ws_service.py   # WebSocket服务
└── frontend/           # React前端应用
    ├── package.json   # Node.js依赖
    ├── vite.config.ts # Vite构建配置
    ├── tsconfig.json  # TypeScript配置
    ├── public/
    │   └── index.html # HTML入口
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

## 后端架构

### 1. 主应用 (main.py)
**作用**: FastAPI应用入口，定义所有API路由和WebSocket端点

**主要功能**:
- 配置CORS中间件
- 定义依赖注入（数据库会话、当前用户）
- 实现启动事件（数据库初始化）
- 认证相关接口（注册、登录、获取当前用户）
- 用户相关接口（获取所有用户）
- 聊天室相关接口（创建、获取、添加成员）
- 消息相关接口（获取消息历史）
- WebSocket端点（实时消息推送）

### 2. 数据库配置 (database.py)
**作用**: 配置数据库连接和会话管理

**主要功能**:
- 创建SQLAlchemy引擎
- 配置连接池
- 定义会话工厂
- 提供依赖注入函数 `get_db()`
- 定义数据库初始化函数 `init_db()`

### 3. 数据模型层 (models/)

#### user.py
**作用**: 定义用户数据模型

**字段**:
- `id`: 用户唯一标识
- `username`: 用户名（唯一）
- `email`: 邮箱（唯一）
- `hashed_password`: 加密密码
- `created_at`: 创建时间
- `is_online`: 在线状态

**关系**:
- `created_rooms`: 创建的聊天室
- `messages`: 发送的消息
- `room_members`: 参与的聊天室成员关系

#### room.py
**作用**: 定义聊天室和聊天室成员数据模型

**Room表字段**:
- `id`: 聊天室唯一标识
- `name`: 聊天室名称
- `creator_id`: 创建者ID
- `created_at`: 创建时间

**RoomMember表字段**:
- `id`: 关系唯一标识
- `room_id`: 聊天室ID
- `user_id`: 用户ID
- `joined_at`: 加入时间

**关系**:
- Room与User、Message、RoomMember关联
- RoomMember与Room和User关联

#### message.py
**作用**: 定义消息数据模型

**字段**:
- `id`: 消息唯一标识
- `room_id`: 所属聊天室ID
- `sender_id`: 发送者ID
- `content`: 消息内容
- `created_at`: 发送时间

**关系**:
- 与Room和User关联

### 4. 数据验证模式层 (schemas/)

#### user.py
**作用**: 定义用户相关的Pydantic模式

**模式**:
- `UserBase`: 用户基础字段（用户名、邮箱）
- `UserCreate`: 用户注册（继承UserBase，添加密码）
- `UserLogin`: 用户登录（用户名、密码）
- `UserResponse`: 用户响应（包含所有公开字段）
- `Token`: JWT令牌响应
- `TokenData`: 令牌数据

#### room.py
**作用**: 定义聊天室相关的Pydantic模式

**模式**:
- `RoomBase`: 聊天室基础字段（名称）
- `RoomCreate`: 创建聊天室
- `RoomResponse`: 聊天室响应
- `RoomDetail`: 聊天室详情（包含成员列表）
- `AddMember`: 添加成员请求

#### message.py
**作用**: 定义消息相关的Pydantic模式

**模式**:
- `MessageBase`: 消息基础字段（房间ID、内容）
- `MessageCreate`: 创建消息
- `MessageResponse`: 消息响应（包含发送者信息）
- `WSMessage`: WebSocket消息格式

### 5. 业务逻辑层 (services/)

#### auth_service.py
**作用**: 处理用户认证相关业务逻辑

**主要功能**:
- 密码加密和验证（bcrypt）
- JWT令牌创建和验证
- 用户CRUD操作
- 用户身份验证

**核心函数**:
- `verify_password()`: 验证密码
- `get_password_hash()`: 加密密码
- `create_access_token()`: 创建JWT令牌
- `verify_token()`: 验证JWT令牌
- `get_user_by_username()`: 根据用户名获取用户
- `get_user_by_email()`: 根据邮箱获取用户
- `get_user_by_id()`: 根据ID获取用户
- `create_user()`: 创建新用户
- `authenticate_user()`: 验证用户身份

#### chat_service.py
**作用**: 处理聊天室和消息相关业务逻辑

**主要功能**:
- 聊天室管理（创建、查询）
- 聊天室成员管理（添加、查询）
- 消息管理（创建、查询历史）
- 用户管理（查询所有用户、更新在线状态）

**核心函数**:
- `create_room()`: 创建聊天室
- `get_room()`: 获取聊天室
- `get_user_rooms()`: 获取用户所在聊天室
- `get_room_detail()`: 获取聊天室详情
- `add_member_to_room()`: 添加成员到聊天室
- `is_room_member()`: 检查用户是否为房间成员
- `create_message()`: 创建消息
- `get_room_messages()`: 获取聊天室消息
- `get_all_users()`: 获取所有用户
- `update_user_online_status()`: 更新用户在线状态

#### ws_service.py
**作用**: 管理WebSocket连接和消息推送

**核心类: ConnectionManager**
- `active_connections`: 存储所有活跃的WebSocket连接
- `connect()`: 建立WebSocket连接
- `disconnect()`: 断开WebSocket连接
- `send_personal_message()`: 发送个人消息
- `broadcast_to_room()`: 向聊天室广播消息
- `broadcast_online_users()`: 广播在线用户列表
- `get_online_users()`: 获取在线用户列表

## 前端架构

### 1. 应用入口 (main.tsx)
**作用**: React应用的入口文件

**功能**: 将App组件挂载到DOM

### 2. 主应用 (App.tsx)
**作用**: 定义应用路由和布局

**功能**:
- 使用BrowserRouter进行路由管理
- 使用WebSocketProvider提供WebSocket上下文
- 定义路由：
  - `/login`: 登录页面
  - `/register`: 注册页面
  - `/`: 聊天室主页面（需要认证）
- 实现私有路由保护

### 3. 登录页面 (Login.tsx)
**作用**: 用户登录界面

**功能**:
- 表单输入（用户名、密码）
- 调用登录API
- 存储JWT令牌到localStorage
- 登录成功后跳转到主页
- 错误处理和提示

### 4. 注册页面 (Register.tsx)
**作用**: 用户注册界面

**功能**:
- 表单输入（用户名、邮箱、密码、确认密码）
- 密码验证（长度、一致性）
- 调用注册API
- 注册成功后跳转到登录页
- 错误处理和提示

### 5. 聊天室主界面 (ChatRoom.tsx)
**作用**: 聊天应用的主要交互界面

**功能**:
- 显示用户信息和退出登录
- 显示聊天室列表
- 创建新聊天室
- 选择聊天室查看消息
- 发送和接收消息
- 显示在线用户数量
- 集成WebSocket实时通信
- 自动滚动到最新消息

### 6. 用户列表组件 (UserList.tsx)
**作用**: 显示所有用户及其在线状态

**功能**:
- 加载所有用户
- 显示用户在线状态
- 邀请用户到当前聊天室
- 只显示非当前用户的邀请按钮

### 7. WebSocket上下文 (WebSocketContext.tsx)
**作用**: 提供全局WebSocket连接管理

**功能**:
- 建立WebSocket连接
- 自动重连机制（5秒后重试）
- 管理在线用户列表
- 发送消息
- 接收消息并通知订阅者
- 提供useWebSocket钩子

### 8. API封装 (api.ts)
**作用**: 封装所有HTTP API调用

**主要模块**:
- `authAPI`: 认证相关API
  - register(): 用户注册
  - login(): 用户登录
  - getMe(): 获取当前用户信息
- `userAPI`: 用户相关API
  - getAll(): 获取所有用户
- `roomAPI`: 聊天室相关API
  - create(): 创建聊天室
  - getAll(): 获取用户聊天室
  - getDetail(): 获取聊天室详情
  - addMember(): 添加成员
- `messageAPI`: 消息相关API
  - getRoomMessages(): 获取聊天室消息

**功能**:
- 统一的axios实例配置
- 自动添加JWT令牌到请求头
- 响应拦截器处理401错误

### 9. 类型定义 (types.ts)
**作用**: 定义TypeScript类型接口

**主要接口**:
- `User`: 用户数据结构
- `Room`: 聊天室数据结构
- `RoomDetail`: 聊天室详情（包含成员）
- `Message`: 消息数据结构
- `WSMessage`: WebSocket消息格式

### 10. 构建配置

#### package.json
**作用**: 定义Node.js依赖和脚本

**主要依赖**:
- react: React框架
- react-dom: React DOM
- react-router-dom: 路由管理
- axios: HTTP客户端

**脚本**:
- `dev`: 启动开发服务器
- `build`: 构建生产版本
- `preview`: 预览生产构建

#### vite.config.ts
**作用**: Vite构建工具配置

**功能**:
- 配置React插件
- 开发服务器端口（3000）
- API代理配置（/api -> localhost:8000）
- WebSocket代理配置

## 数据库设计

### 用户表 (users)
| 字段 | 类型 | 说明 | 索引 |
|------|------|------|------|
| id | INT | 主键 | PRIMARY |
| username | VARCHAR(50) | 用户名 | UNIQUE |
| email | VARCHAR(100) | 邮箱 | UNIQUE |
| hashed_password | VARCHAR(255) | 加密密码 | - |
| created_at | DATETIME | 创建时间 | - |
| is_online | INT | 在线状态(0/1) | - |

### 聊天室表 (rooms)
| 字段 | 类型 | 说明 | 索引 |
|------|------|------|------|
| id | INT | 主键 | PRIMARY |
| name | VARCHAR(100) | 聊天室名称 | - |
| creator_id | INT | 创建者ID | FOREIGN KEY |
| created_at | DATETIME | 创建时间 | - |

### 聊天室成员表 (room_members)
| 字段 | 类型 | 说明 | 索引 |
|------|------|------|------|
| id | INT | 主键 | PRIMARY |
| room_id | INT | 聊天室ID | FOREIGN KEY |
| user_id | INT | 用户ID | FOREIGN KEY |
| joined_at | DATETIME | 加入时间 | - |

### 消息表 (messages)
| 字段 | 类型 | 说明 | 索引 |
|------|------|------|------|
| id | INT | 主键 | PRIMARY |
| room_id | INT | 聊天室ID | FOREIGN KEY |
| sender_id | INT | 发送者ID | FOREIGN KEY |
| content | TEXT | 消息内容 | - |
| created_at | DATETIME | 发送时间 | - |

## API端点

### 认证接口
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `GET /api/auth/me` - 获取当前用户信息

### 用户接口
- `GET /api/users` - 获取所有用户列表

### 聊天室接口
- `POST /api/rooms` - 创建聊天室
- `GET /api/rooms` - 获取用户所在聊天室
- `GET /api/rooms/{room_id}` - 获取聊天室详情
- `POST /api/rooms/members` - 添加成员到聊天室

### 消息接口
- `GET /api/rooms/{room_id}/messages` - 获取聊天室消息

### WebSocket
- `WS /ws/{token}` - WebSocket实时通信端点

## 技术栈

### 后端
- **FastAPI**: 现代高性能Web框架
- **SQLAlchemy**: Python ORM工具
- **PyMySQL**: MySQL驱动
- **python-jose**: JWT处理
- **passlib**: 密码加密
- **WebSocket**: 实时通信

### 前端
- **React 18**: UI框架
- **TypeScript**: 类型安全
- **React Router**: 路由管理
- **Axios**: HTTP客户端
- **Vite**: 构建工具

## 安全特性

1. **密码加密**: 使用bcrypt加密存储用户密码
2. **JWT认证**: 使用JSON Web Token进行身份验证
3. **CORS配置**: 允许跨域请求（生产环境建议配置白名单）
4. **输入验证**: 使用Pydantic进行数据验证
5. **SQL注入防护**: 使用ORM参数化查询

## 实时通信机制

1. **WebSocket连接**: 使用WebSocket建立持久连接
2. **连接管理**: ConnectionManager管理所有活跃连接
3. **消息推送**:
   - 点对点消息推送
   - 聊天室广播
   - 在线用户状态广播
4. **自动重连**: 断线后5秒自动重连

## 部署方式

1. **本地开发**:
   - 后端: `python main.py`
   - 前端: `npm run dev`

2. **Docker部署**:
   ```bash
   docker build -t chat-app .
   docker run -d -p 8000:8000 chat-app
   ```

## 注意事项

1. 生产环境需要修改JWT密钥（SECRET_KEY）
2. 生产环境建议使用HTTPS
3. 数据库连接信息需要根据实际环境配置
4. 建议配置日志记录
5. 建议添加速率限制防止滥用
