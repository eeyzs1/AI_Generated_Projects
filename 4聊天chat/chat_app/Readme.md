# Chat App

一个类似微信的简单聊天应用，使用Python和FastAPI框架开发，前端使用React和TypeScript。

## 功能特性

- **用户注册和登录**：支持用户注册新账户并登录，密码加密存储
- **聊天室功能**：用户可以创建聊天室并邀请其他用户加入
- **消息发送和接收**：支持在聊天室内发送和接收文本消息
- **在线用户列表**：实时显示当前在线用户的列表
- **WebSocket实时通信**：使用WebSocket实现实时消息传递和在线状态更新

## 技术栈

### 后端
- Python 3.9+
- FastAPI
- SQLAlchemy ORM
- MySQL
- JWT认证
- WebSocket

### 前端
- React 18+
- TypeScript
- React Router
- WebSocket API

### 部署
- Docker

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

## 安装和运行

### 前提条件

- Python 3.9+
- MySQL 5.7+
- Node.js 14+

### 后端安装

1. 克隆项目到本地

2. 进入项目目录
   ```bash
   cd chat_app
   ```

3. 安装Python依赖
   ```bash
   pip install -r requirements.txt
   ```

4. 修改数据库配置
   编辑 `database.py` 文件，修改数据库连接信息：
   ```python
   DATABASE_URL = "mysql+pymysql://root:password@localhost:3306/chat_app"
   ```
   确保MySQL数据库已创建，数据库名为 `chat_app`。

5. 运行后端服务
   ```bash
   uvicorn main:app --reload
   ```
   后端服务将运行在 http://localhost:8000

### 前端安装

1. 进入前端目录
   ```bash
   cd frontend
   ```

2. 安装前端依赖
   ```bash
   npm install
   ```

3. 运行前端服务
   ```bash
   npm start
   ```
   前端服务将运行在 http://localhost:3000

### Docker部署

1. 构建Docker镜像
   ```bash
   docker build -t chat-app .
   ```

2. 运行Docker容器
   ```bash
   docker run -p 8000:8000 chat-app
   ```

## API端点

### 用户相关
- **POST /register**：用户注册
- **POST /login**：用户登录
- **GET /users/me**：获取当前用户信息

### 聊天室相关
- **POST /rooms**：创建聊天室
- **GET /rooms**：获取用户的聊天室列表
- **GET /rooms/{room_id}**：获取聊天室详情
- **POST /rooms/{room_id}/add/{user_id}**：添加用户到聊天室

### 消息相关
- **POST /messages**：发送消息
- **GET /rooms/{room_id}/messages**：获取聊天室消息

### WebSocket
- **WS /ws/{user_id}**：WebSocket连接端点

## 使用说明

1. 打开 http://localhost:3000
2. 注册一个新账户或登录现有账户
3. 创建一个新的聊天室
4. 邀请其他用户加入聊天室
5. 开始发送和接收消息

## 注意事项

- 数据库需要预先创建，名称为 `chat_app`
- 默认数据库连接信息为：user=root, password=password, host=localhost, port=3306
- 生产环境中应修改JWT密钥和数据库连接信息
- 前端使用的是模拟数据获取用户列表，实际项目中需要添加相应的API端点

## 许可证

MIT