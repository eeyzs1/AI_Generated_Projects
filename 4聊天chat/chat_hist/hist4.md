# 对话历史：双令牌认证机制改造

## 任务概述
将项目认证机制改造为双令牌（Access Token + Refresh Token）机制。

## 改造过程

### 1. 后端改造

#### 1.1 修改 main.py
- 实现了双令牌机制的核心接口：
  - 登录接口：返回access token和refresh token，同时将refresh token存储到HttpOnly Cookie中
  - 刷新令牌接口：使用refresh token生成新的access token
  - 登出接口：清除refresh token
- 修复了登录接口的JSON响应格式问题，使用FastAPI的JSONResponse替代手动构建响应

#### 1.2 修改 services/auth_service.py
- 实现了令牌生成、验证、存储和撤销的核心逻辑
- 分离了Access Token和Refresh Token的密钥管理，实现了双密钥轮换
- 实现了令牌验证、刷新和撤销功能

#### 1.3 修改 models/refresh_token.py
- 定义了刷新令牌存储模型
- 添加了Boolean类型导入修复NameError

#### 1.4 修改 schemas/user.py
- 定义了Token响应模型结构，包含access_token、refresh_token和token_type

### 2. 前端改造

#### 2.1 修改 src/App.tsx
- 实现了Access Token内存存储和自动刷新机制
- 创建了authenticatedFetch函数，用于带token的API请求
- 实现了token过期时的自动刷新逻辑

#### 2.2 修改 src/Login.tsx
- 处理用户登录逻辑，使用authenticatedFetch进行API请求

#### 2.3 修改 src/UserList.tsx、src/ChatRoom.tsx、src/UserProfile.tsx
- 使用authenticatedFetch替代直接使用localStorage获取token

### 3. 问题及解决方案

#### 3.1 登录时JSON解析错误
- **错误**："Failed to execute 'json' on 'Response': Unexpected end of JSON input"
- **原因**：后端登录接口使用Response手动构建JSON响应时存在格式问题
- **解决方案**：改用FastAPI的JSONResponse自动处理JSON序列化，确保响应格式正确

#### 3.2 点击profile后回到登录界面
- **原因**：使用window.location.href进行导航，导致页面完全刷新，丢失内存中存储的access token
- **解决方案**：使用React Router的useNavigate钩子进行导航，避免页面刷新

#### 3.3 从profile点击back to chat时WebSocket连接失败
- **错误**："WebSocket is closed before the connection is established"
- **原因**：在组件快速卸载时，WebSocket连接还没有完全建立就被关闭
- **解决方案**：
  - 添加了isMounted标志来跟踪组件状态
  - 增强了错误处理，捕获并忽略WebSocket关闭时的错误
  - 改进了关闭逻辑，只在连接状态为OPEN或CONNECTING时才尝试关闭

### 4. 技术选择说明

#### 4.1 为什么选择数据库存储refresh token而不是Redis
- **与现有系统集成简单**：当前应用已经使用SQLite数据库，不需要引入新的依赖
- **数据持久化更可靠**：数据库存储的数据是持久化的，即使系统重启也不会丢失
- **支持复杂查询**：可以方便地执行复杂查询，例如查询用户的所有refresh token
- **实现更简单**：使用现有的ORM框架可以快速实现，代码更简洁
- **适合低频操作**：refresh token的操作频率相对较低，数据库性能完全能够满足需求

## 总结

成功将项目认证机制改造为双令牌（Access Token + Refresh Token）机制，实现了以下功能：

1. **双令牌管理**：Access Token用于短期访问，Refresh Token用于长期刷新
2. **安全存储**：Refresh Token存储在HttpOnly Cookie中，防止XSS攻击
3. **自动刷新**：Access Token过期后自动使用Refresh Token刷新
4. **令牌撤销**：支持主动撤销令牌，增强安全性
5. **前端优化**：使用React Router的useNavigate钩子进行导航，避免页面刷新导致token丢失
6. **错误处理**：增强了WebSocket连接的错误处理，确保在快速导航时不会出现连接失败的错误

改造后的认证机制更加安全、可靠，同时提供了更好的用户体验。