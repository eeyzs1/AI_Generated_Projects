# 聊天应用

这是一个使用Python和FastAPI框架开发的类似微信的简单聊天应用。

## 功能特性

- 用户注册和登录系统
- 聊天室创建和管理
- 实时消息发送和接收
- 在线用户列表显示

## 技术栈

### 后端
- Python 3.9
- FastAPI
- SQLAlchemy ORM
- MySQL
- JWT认证
- WebSocket

### 前端
- React
- TypeScript
- WebSocket API

## 项目结构

```
chat_app/
├── main.py              # 应用入口点
├── database.py          # 数据库连接配置
├── models/              # 数据库模型
│   ├── user.py          # 用户模型
│   ├── room.py          # 聊天室模型
│   └── message.py       # 消息模型
├── schemas/             # Pydantic模型
│   ├── user.py          # 用户相关schema
│   ├── room.py          # 聊天室相关schema
│   └── message.py       # 消息相关schema
├── services/            # 业务逻辑
│   ├── auth_service.py  # 认证服务
│   ├── chat_service.py  # 聊天服务
│   └── ws_service.py    # WebSocket服务
├── frontend/            # 前端代码
│   ├── public/          # 静态资源
│   ├── src/             # 源代码
│   └── package.json     # 前端依赖
├── Dockerfile           # Docker配置
└── requirements.txt     # Python依赖
```

## 快速开始

### 后端设置

1. 安装Python依赖：
```bash
pip install -r requirements.txt
```

2. 配置数据库连接：
编辑`database.py`文件，修改数据库连接URL：
```python
DATABASE_URL = "mysql+pymysql://admin:password@localhost:3306/example_db"
```

3. 运行后端服务：
```bash
uvicorn chat_app.main:app --reload
```

### 前端设置

1. 进入前端目录：
```bash
cd frontend
```

2. 安装前端依赖：
```bash
npm install
```

3. 启动前端服务：
```bash
npm start
```

## API文档

启动后端服务后，可以通过以下URL访问API文档：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Docker部署

1. 构建Docker镜像：
```bash
docker build -t chat-app .
```

2. 运行Docker容器：
```bash
docker run -p 8000:8000 chat-app
```

## 注意事项

- 本项目使用的JWT密钥是硬编码的，在生产环境中应该使用环境变量
- 数据库连接信息应该使用环境变量配置
- 前端API基础URL和WebSocket基础URL可能需要根据部署环境进行调整