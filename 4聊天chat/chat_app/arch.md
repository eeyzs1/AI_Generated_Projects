# 聊天应用项目架构

## 项目结构

```
chat_app/
├── main.py              # 主应用文件，包含所有API端点
├── database.py          # 数据库配置
├── models/              # 数据库模型
│   ├── user.py          # 用户模型
│   ├── room.py          # 聊天室模型
│   └── message.py       # 消息模型
├── schemas/             # Pydantic模型
│   ├── user.py          # 用户相关Schema
│   ├── room.py          # 聊天室相关Schema
│   └── message.py       # 消息相关Schema
├── services/            # 业务逻辑服务
│   ├── auth_service.py  # 认证服务
│   ├── chat_service.py  # 聊天服务
│   └── ws_service.py    # WebSocket服务
├── frontend/            # 前端代码
│   ├── public/          # 静态文件
│   │   └── index.html   # 前端HTML文件
│   ├── src/             # 源代码
│   │   ├── App.tsx      # 应用主组件
│   │   ├── ChatRoom.tsx # 聊天室组件
│   │   ├── Login.tsx    # 登录组件
│   │   ├── Register.tsx # 注册组件
│   │   └── UserList.tsx # 用户列表组件
│   └── package.json     # 前端依赖
├── Dockerfile           # Docker配置
└── requirements.txt     # Python依赖
```

## 文件内容及作用

### 后端文件

#### 1. database.py
- **作用**：配置数据库连接和会话管理
- **内容**：
  - 定义数据库连接URL
  - 创建数据库引擎
  - 配置会话工厂
  - 定义Base基类
  - 提供获取数据库会话的依赖项

#### 2. models/user.py
- **作用**：定义用户数据模型
- **内容**：
  - User类：包含id、username、email、password_hash、created_at、is_active字段
  - 表名为"users"

#### 3. models/room.py
- **作用**：定义聊天室数据模型
- **内容**：
  - room_members关联表：存储房间和用户的多对多关系
  - Room类：包含id、name、creator_id、created_at字段
  - 表名为"rooms"

#### 4. models/message.py
- **作用**：定义消息数据模型
- **内容**：
  - Message类：包含id、sender_id、room_id、content、created_at字段
  - 表名为"messages"

#### 5. schemas/user.py
- **作用**：定义用户相关的Pydantic模型
- **内容**：
  - UserBase：基础用户模型
  - UserCreate：用户创建模型
  - UserLogin：用户登录模型
  - User：用户响应模型
  - Token：令牌模型
  - TokenData：令牌数据模型

#### 6. schemas/room.py
- **作用**：定义聊天室相关的Pydantic模型
- **内容**：
  - RoomBase：基础聊天室模型
  - RoomCreate：聊天室创建模型
  - Room：聊天室响应模型

#### 7. schemas/message.py
- **作用**：定义消息相关的Pydantic模型
- **内容**：
  - MessageBase：基础消息模型
  - MessageCreate：消息创建模型
  - Message：消息响应模型

#### 8. services/auth_service.py
- **作用**：提供认证相关的业务逻辑
- **内容**：
  - 密码验证和哈希生成
  - 用户认证
  - JWT令牌创建和验证

#### 9. services/chat_service.py
- **作用**：提供聊天相关的业务逻辑
- **内容**：
  - 创建聊天室
  - 获取用户的聊天室列表
  - 获取聊天室详情
  - 添加用户到聊天室
  - 检查用户是否在聊天室中
  - 发送消息
  - 获取聊天室消息
  - 获取聊天室成员

#### 10. services/ws_service.py
- **作用**：提供WebSocket相关的服务
- **内容**：
  - ConnectionManager类：管理WebSocket连接
  - 处理用户连接和断开
  - 发送个人消息和广播消息
  - 管理用户房间关系
  - 获取在线用户列表

#### 11. main.py
- **作用**：主应用文件，定义API端点和WebSocket处理
- **内容**：
  - 创建数据库表
  - 配置CORS
  - 定义用户注册和登录端点
  - 定义聊天室相关端点
  - 定义消息相关端点
  - 定义WebSocket端点
  - 提供获取当前用户信息的端点

### 前端文件

#### 1. frontend/package.json
- **作用**：定义前端项目依赖
- **内容**：
  - React及相关依赖
  - TypeScript
  - 项目脚本配置

#### 2. frontend/public/index.html
- **作用**：前端HTML模板
- **内容**：
  - 基本HTML结构
  - 内联CSS样式
  - React应用挂载点

#### 3. frontend/src/App.tsx
- **作用**：应用主组件
- **内容**：
  - 路由配置
  - 用户状态管理
  - 登录和注销处理

#### 4. frontend/src/Login.tsx
- **作用**：登录组件
- **内容**：
  - 登录表单
  - 登录逻辑处理
  - 错误提示

#### 5. frontend/src/Register.tsx
- **作用**：注册组件
- **内容**：
  - 注册表单
  - 注册逻辑处理
  - 错误和成功提示

#### 6. frontend/src/ChatRoom.tsx
- **作用**：聊天室组件
- **内容**：
  - 聊天室列表
  - 消息展示
  - 消息发送
  - WebSocket连接管理
  - 在线用户列表

#### 7. frontend/src/UserList.tsx
- **作用**：用户列表组件
- **内容**：
  - 用户列表展示
  - 邀请用户到聊天室功能

### 配置文件

#### 1. Dockerfile
- **作用**：配置Docker容器
- **内容**：
  - 基础镜像设置
  - 依赖安装
  - 项目文件复制
  - 端口暴露
  - 启动命令

#### 2. requirements.txt
- **作用**：定义Python依赖
- **内容**：
  - FastAPI及相关依赖
  - 数据库驱动
  - 认证相关库
  - WebSocket库

## 技术架构

### 后端架构
- **框架**：FastAPI
- **数据库**：MySQL + SQLAlchemy ORM
- **认证**：JWT
- **实时通信**：WebSocket
- **部署**：Docker

### 前端架构
- **框架**：React + TypeScript
- **路由**：React Router
- **状态管理**：React useState
- **WebSocket**：原生WebSocket API

### 数据流
1. 用户注册/登录 → 后端验证 → 返回JWT令牌
2. 前端存储令牌 → 后续请求携带令牌
3. 创建/加入聊天室 → 后端验证权限 → 建立WebSocket连接
4. 发送消息 → WebSocket传输 → 后端处理 → 广播给房间成员
5. 接收消息 → WebSocket推送 → 前端更新界面

## 安全考虑
- 密码加密存储
- JWT令牌认证
- 权限验证（用户只能访问自己的资源）
- WebSocket连接验证

## 扩展性
- 模块化设计，易于添加新功能
- 服务层分离，业务逻辑与API分离
- 前端组件化，易于维护和扩展