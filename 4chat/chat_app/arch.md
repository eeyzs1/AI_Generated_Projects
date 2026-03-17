# 聊天应用项目架构

## 项目结构

```
chat_app/
├── main.py              # 主应用文件，包含所有API端点
├── database.py          # 数据库配置
├── models/              # 数据库模型
│   ├── user.py          # 用户模型
│   ├── room.py          # 聊天室模型│   ├── message.py       # 消息模型
│   ├── refresh_token.py # 刷新令牌模型
│   └── contact.py       # 联系人模型
├── schemas/             # Pydantic模型
│   ├── user.py          # 用户相关Schema
│   ├── room.py          # 聊天室相关Schema
│   ├── message.py       # 消息相关Schema
│   └── contact.py       # 联系人相关Schema
├── services/            # 业务逻辑服务
│   ├── auth_service.py  # 认证服务
│   ├── chat_service.py  # 聊天服务
│   ├── ws_service.py    # WebSocket服务
│   └── contact_service.py # 联系人服务
├── frontend/            # 前端代码
│   ├── public/          # 静态文件
│   │   └── index.html   # 前端HTML文件
│   ├── src/             # 源代码
│   │   ├── App.tsx      # 应用主组件
│   │   ├── ChatRoom.tsx # 聊天室组件
│   │   ├── Login.tsx    # 登录组件
│   │   ├── Register.tsx # 注册组件
│   │   ├── UserList.tsx # 用户列表组件
│   │   ├── UserProfile.tsx # 用户中心组件
│   │   ├── VerifyEmail.tsx # 邮箱验证组件
│   │   ├── PasswordResetRequest.tsx # 密码重置请求组件
│   │   ├── PasswordReset.tsx # 密码重置组件
│   │   ├── Contacts.tsx # 联系人列表组件
│   │   └── ContactProfile.tsx # 联系人详情组件
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
  - User类：包含id、username、displayname、email、password_hash、created_at、is_active、avatar字段
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

#### 5. models/refresh_token.py
- **作用**：定义刷新令牌数据模型
- **内容**：
  - RefreshToken类：包含id、user_id、token、expires_at字段
  - 表名为"refresh_tokens"

#### 6. models/contact.py
- **作用**：定义联系人数据模型
- **内容**：
  - Contact类：包含id、requester_id、addressee_id、status、created_at字段
  - 表名为"contacts"

#### 7. schemas/user.py
- **作用**：定义用户相关的Pydantic模型
- **内容**：
  - UserBase：基础用户模型
  - UserCreate：用户创建模型
  - UserLogin：用户登录模型
  - User：用户响应模型
  - Token：令牌模型
  - TokenData：令牌数据模型

#### 8. schemas/room.py
- **作用**：定义聊天室相关的Pydantic模型
- **内容**：
  - RoomBase：基础聊天室模型
  - RoomCreate：聊天室创建模型
  - Room：聊天室响应模型

#### 9. schemas/message.py
- **作用**：定义消息相关的Pydantic模型
- **内容**：
  - MessageBase：基础消息模型
  - MessageCreate：消息创建模型
  - Message：消息响应模型

#### 10. schemas/contact.py
- **作用**：定义联系人相关的Pydantic模型
- **内容**：
  - ContactBase：基础联系人模型
  - ContactCreate：联系人创建模型
  - Contact：联系人响应模型

#### 11. services/auth_service.py
- **作用**：提供认证相关的业务逻辑
- **内容**：
  - 密码验证和哈希生成
  - 用户认证
  - JWT令牌创建和验证
  - 双令牌（Access Token + Refresh Token）机制
  - 令牌自动刷新
  - 令牌撤销

#### 12. services/chat_service.py
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

#### 13. services/ws_service.py
- **作用**：提供WebSocket相关的服务
- **内容**：
  - ConnectionManager类：管理WebSocket连接
  - 处理用户连接和断开
  - 发送个人消息和广播消息
  - 管理用户房间关系
  - 获取在线用户列表

#### 14. services/contact_service.py
- **作用**：提供联系人相关的业务逻辑
- **内容**：
  - 发送联系人请求
  - 接受/拒绝联系人请求
  - 获取用户的联系人列表
  - 删除联系人
  - 搜索用户

#### 15. main.py
- **作用**：主应用文件，定义API端点和WebSocket处理
- **内容**：
  - 创建数据库表
  - 配置CORS
  - 定义用户注册和登录端点
  - 定义聊天室相关端点
  - 定义消息相关端点
  - 定义WebSocket端点
  - 提供获取当前用户信息的端点
  - 定义邮箱验证端点
  - 定义密码重置端点
  - 定义联系人相关端点
  - 定义头像上传端点

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
  - 忘记密码链接

#### 5. frontend/src/Register.tsx
- **作用**：注册组件
- **内容**：
  - 注册表单
  - 注册逻辑处理
  - 错误和成功提示
  - 头像选择和上传
  - 圆形头像裁剪功能

#### 6. frontend/src/ChatRoom.tsx
- **作用**：聊天室组件
- **内容**：
  - 左侧边栏：房间列表、创建新房间功能、邀请处理
  - 右侧：聊天界面、消息列表、发送消息功能、成员管理
  - WebSocket连接管理
  - 在线用户列表
  - 类似微信/钉钉的布局

#### 7. frontend/src/UserList.tsx
- **作用**：用户列表组件
- **内容**：
  - 用户列表展示
  - 邀请用户到聊天室功能

#### 8. frontend/src/UserProfile.tsx
- **作用**：用户中心组件
- **内容**：
  - 个人信息展示
  - 个人信息修改
  - 头像上传和裁剪
  - 密码修改

#### 9. frontend/src/VerifyEmail.tsx
- **作用**：邮箱验证组件
- **内容**：
  - 邮箱验证逻辑
  - 验证结果展示

#### 10. frontend/src/PasswordResetRequest.tsx
- **作用**：密码重置请求组件
- **内容**：
  - 密码重置请求表单
  - 邮箱发送逻辑

#### 11. frontend/src/PasswordReset.tsx
- **作用**：密码重置组件
- **内容**：
  - 新密码设置表单
  - 密码重置逻辑

#### 12. frontend/src/Contacts.tsx
- **作用**：联系人列表组件
- **内容**：
  - 联系人列表展示（按字母顺序排序）
  - 联系人搜索功能
  - 联系人请求处理

#### 13. frontend/src/ContactProfile.tsx
- **作用**：联系人详情组件
- **内容**：
  - 联系人信息展示
  - 发送消息按钮
  - 自动创建双人聊天室

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
- **数据库**：SQLite + SQLAlchemy ORM（支持MySQL）
- **认证**：JWT（双令牌机制：Access Token + Refresh Token）
- **实时通信**：WebSocket
- **部署**：Docker
- **文件上传**：支持头像上传和验证
- **邮箱服务**：支持邮箱验证和密码重置

### 前端架构
- **框架**：React + TypeScript
- **路由**：React Router
- **状态管理**：React useState
- **WebSocket**：原生WebSocket API（优化了连接管理）
- **UI库**：Ant Design
- **布局**：类似微信/钉钉的侧边栏布局
- **头像处理**：支持圆形头像裁剪和上传

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