# 4Chat — 即时通讯系统

一个基于微服务架构的即时通讯 Web 应用，支持用户注册登录、好友管理、群聊室、实时消息推送等功能。

---

## 目录

- [项目功能](#项目功能)
- [技术架构](#技术架构)
- [数据流动说明](#数据流动说明)
- [项目结构](#项目结构)
- [部署方式总览](#部署方式总览)
- [方案一：Docker Compose 本地全栈](#方案一docker-compose-本地全栈)
- [方案二：Docker Compose 云服务中间件](#方案二docker-compose-云服务中间件)
- [方案三：Kubernetes 本地 minikube](#方案三kubernetes-本地-minikube)
- [方案三B：Kubernetes Helm 部署](#方案三bkubernetes-helm-部署)
- [方案四：Kubernetes 云服务中间件](#方案四kubernetes-云服务中间件)
- [Elasticsearch 集成方案](#elasticsearch-集成方案)
- [CDN 集成方案](#cdn-集成方案)
- [Celery 集成方案](#celery-集成方案)
- [使用说明](#使用说明)
- [常见问题](#常见问题)

---

## 项目功能

- 用户注册 / 登录 / 邮箱验证 / 密码重置
- 好友申请与管理
- 创建聊天室、邀请好友加入
- 实时消息收发（WebSocket）
- 消息全文搜索（Elasticsearch）
- 头像上传与默认头像选择
- 静态资源与文件 CDN 加速
- 离线消息邮件通知

---

## 技术架构

整个系统由 6 个后端微服务组成，通过 APISIX 网关统一对外提供服务。

```
浏览器
  │
  ▼
CDN (cdn.4chat.example.com)  ── 静态资源 / 头像 / 文件加速
  │
  ▼
APISIX 网关 (localhost:8080)
  │
  ├── /api/user/*     → user-service      用户、登录、好友
  ├── /api/group/*    → group-service     聊天室、邀请
  ├── /api/message/*  → message-service   消息存储（ScyllaDB）
  ├── /api/search/*   → search-service    全文搜索（Elasticsearch）
  ├── /ws/*           → connector-service WebSocket 实时连接
  └── /api/storage/*  → storage-service   头像文件（CDN 回源）
```

**中间件：**

| 组件 | 用途 |
|------|------|
| MySQL | 持久化存储用户、群组数据 |
| ScyllaDB | 消息存储（时序数据，高吞吐） |
| Elasticsearch | 消息全文搜索、用户模糊搜索、房间搜索 |
| Redis | 在线状态缓存、用户信息缓存 |
| Kafka | 服务间异步消息传递 |
| Celery | 异步任务队列（邮件、定时任务、ES 重建索引等） |
| Nacos | 服务注册与发现 |
| CDN | 静态资源、头像、文件分发加速 |

---

## 数据流动说明

### 1. 用户注册 / 登录

```
浏览器
  │ POST /api/user/register 或 /api/user/login
  ▼
APISIX 网关
  │ 转发
  ▼
user-service
  │ 写入用户数据
  ├──▶ MySQL (im_user)        — 持久化用户信息
  │ 生成 JWT token
  │ 缓存用户信息
  └──▶ Redis                  — SET user:{id} = {...} (TTL 5分钟)
  │
  ▼
浏览器收到 access_token + refresh_token
```

---

### 2. 发送消息（核心流程）

```
浏览器
  │ POST /api/message/send  (携带 JWT)
  ▼
APISIX 网关
  │ 转发
  ▼
message-service
  │ 验证 JWT
  │ 检查用户是否在房间内
  ├──▶ group-service (HTTP /internal/rooms/{id}/check-member)
  │ 保存消息
  ├──▶ ScyllaDB (im_message)  — 持久化消息记录（时序存储）
  │ 获取发送者信息
  ├──▶ user-service (HTTP /internal/users/{id})  — 先查 Redis 缓存，未命中再查 MySQL
  │ 发布事件
  └──▶ Kafka (topic: msg_sent) — 异步通知其他服务
         │
         ├──▶ connector-service 消费
         │      │ 查询房间成员
         │      ├──▶ group-service (HTTP /internal/rooms/{id}/members)
         │      │ 推送给在线成员
         │      └──▶ WebSocket 连接 — 实时推送到浏览器
         │
         └──▶ push-service 消费
                │ 查询房间成员
                ├──▶ group-service (HTTP /internal/rooms/{id}/members)
                │ 检查在线状态
                ├──▶ Redis (SISMEMBER online_users)
                │ 对离线成员发邮件
                └──▶ SMTP — 离线通知邮件
```

---

### 3. WebSocket 连接（实时通道建立）

```
浏览器
  │ WS /ws/connect?token=xxx&user_id=xxx
  ▼
APISIX 网关
  │ 转发 WebSocket 升级请求
  ▼
connector-service
  │ 验证 JWT token
  │ 注册连接
  ├──▶ Redis (SADD online_users {user_id})  — 标记用户在线
  │ 保持长连接，等待 Kafka 消息推送
  │
  │ 断开时
  └──▶ Redis (SREM online_users {user_id})  — 标记用户离线
```

---

### 4. 头像上传

```
浏览器
  │ POST /api/storage/upload (multipart/form-data)
  ▼
APISIX 网关
  ▼
storage-service
  │ 验证 JWT
  │ 保存文件
  └──▶ 本地磁盘 /app/static/avatars/uploads/
         (Docker: storage_data volume)
         (K8s: storage-pvc PersistentVolume)
  │
  ▼
返回文件 URL: /api/storage/static/avatars/uploads/{filename}
  │
  ▼
CDN 回源缓存: cdn.4chat.example.com/static/avatars/uploads/{filename}
```

---

### 5. 消息全文搜索（Elasticsearch）

```
浏览器
  │ GET /api/search/messages?q=关键词&room_id=可选
  ▼
APISIX 网关
  │ 转发
  ▼
search-service
  │ 验证 JWT
  │ 查询 Elasticsearch
  └──▶ Elasticsearch (im_messages 索引)
         │ 全文检索 content 字段（ik 分词器）
         │ 可选按 room_id 过滤
         │ 按相关度 + 时间排序
  │
  ▼
返回搜索结果（含高亮片段）

数据同步流程：
  message-service 保存消息到 ScyllaDB
    → 发布 msg_sent 到 Kafka
    → search-service 消费 msg_sent
    → 写入 Elasticsearch (im_messages 索引)

  user-service 用户注册/更新
    → 发布 user_updated 到 Kafka
    → search-service 消费 user_updated
    → 写入 Elasticsearch (im_users 索引)

  group-service 房间创建/更新
    → 发布 room_updated 到 Kafka
    → search-service 消费 room_updated
    → 写入 Elasticsearch (im_rooms 索引)
```

---

### 6. CDN 加速流程

```
静态资源访问（前端 JS/CSS/HTML）：
  浏览器 → CDN 边缘节点
    │ 命中缓存 → 直接返回
    │ 未命中   → 回源到前端 Nginx → 缓存并返回

头像/文件访问：
  浏览器 → CDN (cdn.4chat.example.com/static/avatars/...)
    │ 命中缓存 → 直接返回（默认头像缓存1天，上传头像缓存1小时）
    │ 未命中   → 回源到 storage-service → 缓存并返回

头像上传：
  浏览器 → APISIX → storage-service
    │ 保存到本地磁盘
    │ 返回 CDN URL: https://cdn.4chat.example.com/static/avatars/uploads/{filename}
    │ CDN 首次访问时回源拉取并缓存
```

---

### 5. 服务发现数据流

```
各服务启动时
  └──▶ Nacos — 注册自身 IP:Port

服务间调用时 (nacos_client.py)
  ├── 查询 Nacos 获取目标服务实例列表
  ├── 随机选一个实例（客户端负载均衡）
  └── 若 Nacos 不可用 → 回退到环境变量硬编码地址
```

---

### 6. Docker Compose 下的网络

```
所有容器在同一个 bridge 网络内
容器名即主机名，直接通过服务名互访：

  message-service  ──HTTP──▶  user-service:8001
  message-service  ──HTTP──▶  group-service:8002
  connector-service ──TCP──▶  kafka:9092
  user-service      ──TCP──▶  mysql:3306
  user-service      ──TCP──▶  redis:6379
```

---

### 7. Kubernetes 下的网络

```
每个服务对应一个 K8s Service（ClusterIP）
Pod 通过 Service DNS 名互访：

  message-service Pod
    ──▶ http://user-service:8001    (K8s DNS 解析到 user-service ClusterIP)
    ──▶ http://group-service:8002
    ──▶ kafka:9092

外部流量入口：
  浏览器 ──▶ NodePort/LoadBalancer ──▶ APISIX Pod ──▶ 各服务 ClusterIP

多集群（Istio）：
  集群A Pod ──▶ East-West Gateway:15443 ──▶ 集群B Pod
  (mTLS 加密，Istio sidecar 自动处理)
```

---

### 数据存储分布总览

| 数据类型 | 存储位置 | 说明 |
|---------|---------|------|
| 用户信息 | MySQL (im_user) | 持久化 |
| 群组/房间 | MySQL (im_group) | 持久化 |
| 消息记录 | ScyllaDB (im_message) | 持久化，时序优化 |
| 消息搜索索引 | Elasticsearch (im_messages) | 全文搜索，ik 分词 |
| 用户搜索索引 | Elasticsearch (im_users) | 模糊搜索，前缀匹配 |
| 房间搜索索引 | Elasticsearch (im_rooms) | 名称搜索 |
| 头像文件 | 本地磁盘 / PV | 持久化，CDN 加速分发 |
| 前端静态资源 | Nginx / CDN | CDN 加速分发 |
| 用户缓存 | Redis `user:{id}` | TTL 5分钟，加速查询 |
| 在线状态 | Redis `online_users` | Set，实时更新 |
| 消息事件 | Kafka `msg_sent` | 异步，消费后丢弃 |
| 搜索同步事件 | Kafka `user_updated` / `room_updated` | 异步同步到 ES |
| Celery 任务状态 | Redis `celery-task-meta-*` | Celery 结果后端 |
| Celery 定时调度 | Redis `celery-beat` | Celery Beat 调度器 |
| 服务注册 | Nacos | 内存+持久化，服务发现 |
| JWT token | 浏览器 localStorage | 客户端持有 |
| Refresh token | MySQL + Cookie | 服务端验证 |

---

## 微服务代码结构说明

### user-service（端口 8001）

```
services/user-service/
├── main.py                       # 路由入口：注册、登录、邮箱验证、密码重置、好友管理、内部用户查询接口
├── database.py                   # SQLAlchemy 连接 MySQL im_user 数据库
├── auth.py                       # 从请求头提取并验证 JWT，返回当前用户 ID
├── nacos_client.py               # 启动时向 Nacos 注册自身，提供服务地址查询
├── ha_database.py                # 高可用模式：MySQL 读写分离 + Redis 三模式切换
├── models/
│   ├── user.py                   # 用户表 ORM：用户名、密码哈希、邮箱、头像、验证状态
│   ├── contact.py                # 好友关系表 ORM：发起方、接收方、状态（pending/accepted）
│   └── refresh_token.py          # Refresh Token 表 ORM：JTI、过期时间、是否已撤销
├── schemas/
│   ├── user.py                   # Pydantic 模型：注册/登录请求、用户信息响应、Token 响应
│   └── contact.py                # Pydantic 模型：好友申请请求、好友列表响应
└── services/
    ├── auth_service.py           # 核心认证逻辑：密码哈希、JWT 签发/刷新/撤销、邮件发送
    └── contact_service.py        # 好友业务逻辑：发送申请、接受/拒绝、查询好友列表
```

### group-service（端口 8002）

```
services/group-service/
├── main.py                       # 路由入口：创建房间、加入/退出、邀请、内部成员查询接口
├── database.py                   # SQLAlchemy 连接 MySQL im_group 数据库
├── auth.py                       # JWT 验证中间件
├── nacos_client.py               # Nacos 服务注册与发现
├── ha_database.py                # 高可用数据库工具
├── models/
│   └── room.py                   # 房间表、房间成员表、邀请表 ORM
├── schemas/
│   └── room.py                   # Pydantic 模型：房间创建、成员信息、邀请请求/响应
└── services/
    └── chat_service.py           # 房间业务逻辑：创建房间、成员管理、邀请流程
```

### message-service（端口 8003）

```
services/message-service/
├── main.py                       # 路由入口：发送消息、查询房间历史消息
├── database.py                   # ScyllaDB 连接，自动初始化 keyspace 和 messages 表
├── auth.py                       # JWT 验证中间件
├── nacos_client.py               # Nacos 服务注册与发现
├── ha_database.py                # 高可用数据库工具
├── models/
│   └── message.py                # CQL 表结构说明（partition key: room_id，clustering: created_at DESC）
├── schemas/
│   └── message.py                # Pydantic 模型：发送请求、消息响应（id 为 UUID）
└── services/
    ├── message_service.py        # 消息存取逻辑：写入 ScyllaDB、按房间分页查询
    └── kafka_producer.py         # aiokafka 生产者：消息保存后发布 msg_sent 事件到 Kafka
```

### connector-service（端口 8004）

```
services/connector-service/
├── main.py                       # WebSocket 端点 /ws/connect，管理连接生命周期，启动 Kafka 消费者
├── auth.py                       # 从 query param 提取 token 并验证（WebSocket 不支持请求头）
├── nacos_client.py               # Nacos 服务注册与发现
├── ha_database.py                # 高可用数据库工具
└── services/
    ├── ws_service.py             # WebSocket 连接管理：内存存储活跃连接，Redis 维护在线用户集合
    └── kafka_consumer.py         # aiokafka 消费者：消费 msg_sent 事件，找到房间在线成员并推送消息
```

### push-service（端口 8005）

```
services/push-service/
├── main.py                       # 健康检查端点，启动时在后台运行 Kafka 消费者
├── nacos_client.py               # Nacos 服务注册与发现
├── ha_database.py                # 高可用数据库工具
└── services/
    ├── kafka_consumer.py         # 消费 msg_sent 事件，查询房间成员，过滤离线用户
    └── push_handler.py           # 离线推送逻辑：通过 SMTP 发送邮件通知
```

### storage-service（端口 8006）

```
services/storage-service/
├── main.py                       # 路由入口：头像上传、默认头像列表、静态文件服务
├── auth.py                       # JWT 验证中间件
├── nacos_client.py               # Nacos 服务注册与发现
├── ha_database.py                # 高可用数据库工具
└── static/avatars/default/       # 内置默认头像文件
```

### search-service（端口 8007）

```
services/search-service/
├── main.py                       # 路由入口：消息搜索、用户搜索、房间搜索
├── database.py                   # Elasticsearch 连接，自动初始化索引和映射
├── auth.py                       # JWT 验证中间件
├── nacos_client.py               # Nacos 服务注册与发现
├── ha_database.py                # 高可用数据库工具
├── schemas/
│   └── search.py                 # Pydantic 模型：搜索请求、搜索结果、高亮片段
└── services/
    ├── search_service.py         # 搜索逻辑：构建 ES 查询、结果解析、高亮处理
    └── kafka_consumer.py         # 消费 msg_sent / user_updated / room_updated 同步到 ES
```

### services/common/（公共工具）

```
services/common/
├── nacos_client.py               # 通用 Nacos 客户端：服务注册、地址查询、客户端负载均衡，不可用时回退环境变量
└── ha_database.py                # 高可用工具：MySQL 读写分离（主库写/从库读）+ Redis 普通/哨兵/集群三模式
```

---

```
4chat/
├── frontend/              # React 前端页面
├── services/
│   ├── user-service/      # 用户、登录、好友 (端口 8001)
│   ├── group-service/     # 聊天室、邀请   (端口 8002)
│   ├── message-service/   # 消息收发       (端口 8003)
│   ├── connector-service/ # WebSocket     (端口 8004)
│   ├── push-service/      # 离线推送       (端口 8005)
│   ├── storage-service/   # 文件存储       (端口 8006)
│   └── search-service/    # 全文搜索       (端口 8007)
├── gateway/
│   ├── apisix.yaml        # 路由配置
│   └── config.yaml        # APISIX 配置
├── k8s/
│   ├── middleware/        # MySQL/Redis/Kafka/Nacos/ScyllaDB/ES K8s 配置
│   ├── services/          # 7个微服务 + 前端 K8s 配置
│   ├── gateway/           # APISIX K8s 配置
│   ├── overlays/cloud/    # Kustomize 云服务中间件 overlay
│   ├── deploy.sh          # kubectl 一键部署脚本
│   └── helm-deploy.sh     # Helm 一键部署脚本
├── helm/
│   ├── middleware/        # Helm chart：中间件
│   ├── services/          # Helm chart：业务服务 + 网关
│   └── 4chat/             # Helm umbrella chart（依赖上述两个）
├── docker-compose.yml         # Docker 本地全栈
├── docker-compose.cloud.yml   # Docker 云服务中间件
├── .env.example               # 环境变量配置示例
└── init.sql                   # 数据库初始化脚本
```

---

## 部署方式总览

| 方案 | 中间件 | 镜像 | 适合场景 |
|------|--------|------|----------|
| Docker Compose 本地全栈 | 本地 Docker | 本地 build | 开发 / 快速体验 |
| Docker Compose 云服务 | 云服务（RDS/ElastiCache/MSK） | 本地 build | 生产（小规模） |
| K8s 本地 minikube（kubectl） | 本地 K8s | 本地 registry 或 Docker Hub | 学习 K8s / 测试 |
| K8s 本地 minikube（Helm） | 本地 K8s | 本地 registry 或 Docker Hub | 学习 Helm / 测试 |
| K8s 云服务中间件 | 云服务 | Docker Hub | 生产（K8s 集群） |

---

## 方案一：Docker Compose 本地全栈

所有服务和中间件全部跑在本地 Docker 里，只需安装 **Docker Desktop**。

- Windows / Mac：下载安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Linux：安装 Docker + Docker Compose

```bash
git clone <项目地址>
cd 4chat
docker-compose up -d
```

首次启动需要几分钟下载镜像。完成后访问 **http://localhost:3000**。

检查服务状态：

```bash
docker-compose ps
```

停止服务：

```bash
docker-compose down        # 保留数据
docker-compose down -v     # 同时清除数据
```

---

## 方案二：Docker Compose 云服务中间件

业务服务跑在 Docker 里，MySQL / Redis / Kafka 使用云服务（如 AWS RDS / ElastiCache / MSK）。

第一步，复制并填写环境变量：

```bash
cp .env.example .env
# 用文本编辑器打开 .env，填写云服务连接信息
```

第二步，启动：

```bash
docker-compose -f docker-compose.cloud.yml up -d
```

`.env` 中需要填写的关键项：
- `MYSQL_*_URL` — 各数据库连接串
- `REDIS_URL` — Redis 连接串
- `KAFKA_BOOTSTRAP_SERVERS` — Kafka broker 地址

---

## 方案三：Kubernetes 本地 minikube

需要安装 [minikube](https://minikube.sigs.k8s.io/docs/start/) 和 [kubectl](https://kubernetes.io/docs/tasks/tools/)。

**使用本地 registry（默认）：**

```bash
./k8s/deploy.sh
```

**使用 Docker Hub：**

```bash
./k8s/deploy.sh --registry dockerhub --hub-user <你的DockerHub用户名>
```

脚本会自动构建镜像、部署中间件和所有服务，完成后输出访问地址：

```
前端地址:  http://<minikube-ip>:30000
API 网关:  http://<minikube-ip>:30080
```

用 `minikube ip` 查看实际 IP。

**其他命令：**

```bash
# 滚动重启所有服务（不重新构建镜像）
./k8s/deploy.sh --restart

# 智能更新（只重建有代码变更的服务）
./k8s/deploy.sh --update

# 只更新某个服务
./k8s/deploy.sh --update user-service

# 卸载
./k8s/deploy.sh --uninstall
```

手动逐步部署：

```bash
kubectl apply -f k8s/middleware/
kubectl wait --for=condition=ready pod -l app=mysql --timeout=180s
kubectl wait --for=condition=ready pod -l app=kafka --timeout=180s
kubectl apply -f k8s/gateway/
kubectl apply -f k8s/services/
kubectl get pods
```

清理：

```bash
./k8s/deploy.sh --uninstall
```

---

## 方案三B：Kubernetes Helm 部署

使用 Helm 包管理器部署，提供更灵活的配置管理和版本控制。

**前置要求：**
- 安装 [Helm v3](https://helm.sh/docs/intro/install/)
- 安装 [minikube](https://minikube.sigs.k8s.io/docs/start/) 和 [kubectl](https://kubernetes.io/docs/tasks/tools/)

**一键部署（推荐）：**

```bash
./k8s/helm-deploy.sh
```

**其他命令：**

```bash
# 使用 Docker Hub
./k8s/helm-deploy.sh --registry dockerhub --hub-user <你的DockerHub用户名>

# 云服务中间件
./k8s/helm-deploy.sh --cloud

# 只部署中间件
./k8s/helm-deploy.sh --only middleware

# 只部署业务服务
./k8s/helm-deploy.sh --only services

# 滚动重启
./k8s/helm-deploy.sh --restart

# 智能更新
./k8s/helm-deploy.sh --update

# 卸载
./k8s/helm-deploy.sh --uninstall
```

**手动 Helm 操作：**

```bash
# 独立部署中间件
helm upgrade --install 4chat-middleware helm/middleware

# 独立部署业务服务
helm upgrade --install 4chat-services helm/services

# 全量部署（umbrella chart）
helm dependency update helm/4chat
helm upgrade --install 4chat helm/4chat

# 查看 releases
helm list

# 卸载
helm uninstall 4chat
```

**Helm Chart 结构：**

```
helm/
├── middleware/     # 独立 chart：MySQL/Redis/Kafka/Nacos/ScyllaDB
├── services/       # 独立 chart：6个微服务 + 前端 + APISIX
└── 4chat/          # Umbrella chart：依赖上述两个 chart
```

**切换部署方式：**

```bash
# kubectl → Helm（数据不丢失）
./k8s/helm-deploy.sh  # 自动认领 PVC

# Helm → kubectl（数据不丢失）
./k8s/deploy.sh       # 自动移除 Helm 标记
```

清理：

```bash
kubectl delete -f k8s/services/
kubectl delete -f k8s/gateway/
kubectl delete -f k8s/middleware/
```

---

## 方案四：Kubernetes 云服务中间件

K8s 集群只跑业务服务，MySQL / Redis / Kafka 使用云服务。

第一步，编辑云服务连接信息：

```bash
# 编辑 k8s/overlays/cloud/cloud-env-patch.yaml
# 填写 DATABASE_URL、REDIS_URL、KAFKA_BOOTSTRAP_SERVERS 等
```

第二步，一键部署（推送到 Docker Hub）：

```bash
./k8s/deploy.sh --registry dockerhub --hub-user <你的DockerHub用户名> --cloud
```

或手动部署：

```bash
kubectl apply -f k8s/gateway/apisix.yaml
kubectl apply -k k8s/overlays/cloud/
```

---

## 高可用中间件部署

### 各中间件高可用方案

| 中间件 | 方案 | 节点数 | 说明 |
|--------|------|--------|------|
| MySQL | 主从复制 | 1主1从 | 写走主库，读走从库 |
| Redis | 哨兵模式（默认）/ 集群模式 | 1主2从3哨兵 或 6节点集群 | 哨兵自动故障转移；集群支持横向扩展 |
| Kafka | 多 Broker | 3个 Broker | 分区副本数3，最少2个同步 |
| Nacos | 集群模式 | 3节点 | 共享 MySQL 存储 |
| Elasticsearch | 集群模式 | 3节点（混合）或 5+节点（专用 master+data） | 2副本，ik 分词插件 |
| Celery Worker | 多实例 | 2+ Worker 实例 | 按队列分流，可独立扩缩容 |

### Docker Compose 高可用启动

```bash
docker-compose -f docker-compose.ha.yml up -d
```

业务服务会自动使用：
- MySQL 主库写、从库读（通过 `DATABASE_SLAVE_URL` 环境变量）
- Redis 哨兵模式（通过 `REDIS_SENTINEL_HOSTS` 环境变量）
- Kafka 3个 Broker（`KAFKA_BOOTSTRAP_SERVERS` 填写所有 Broker 地址）

### Kubernetes 高可用中间件

```bash
# 替换原有单实例中间件
kubectl delete -f k8s/middleware/mysql.yaml
kubectl delete -f k8s/middleware/redis.yaml
kubectl delete -f k8s/middleware/kafka.yaml
kubectl delete -f k8s/middleware/nacos.yaml

# 部署高可用版本
kubectl apply -f k8s/middleware/mysql-ha.yaml
kubectl apply -f k8s/middleware/redis-sentinel.yaml
kubectl apply -f k8s/middleware/kafka-ha.yaml
kubectl apply -f k8s/middleware/nacos-cluster.yaml
```

K8s 服务名对应关系（业务服务无需改动）：

| 原服务名 | HA 服务名 | 说明 |
|---------|----------|------|
| `mysql` | `mysql-master` / `mysql-slave` | 写主读从 |
| `redis` | `redis-master` / `redis-sentinel` | 哨兵自动切换 |
| `kafka` | `kafka-1,kafka-2,kafka-3` | 多 Broker |
| `nacos` | `nacos-client` | 负载均衡到3节点 |

> **Redis 模式切换**（通过环境变量控制，三选一）：
>
> | 模式 | 环境变量 | 适合场景 |
> |------|---------|---------|
> | 普通 | `REDIS_URL=redis://redis:6379/0` | 开发/单机 |
> | 哨兵 | `REDIS_SENTINEL_HOSTS=s1:26379,s2:26379,s3:26379` | 高可用，数据量小 |
> | 集群 | `REDIS_CLUSTER_HOSTS=n1:6379,n2:6379,n3:6379` | 高可用，数据量大 |
>
> K8s 集群模式部署：`kubectl apply -f k8s/middleware/redis-cluster.yaml`

---

### 方案一：Nacos 真正做服务发现（跨区域多实例）

默认架构用 Docker/K8s DNS 硬编码服务名，无法跨区域。升级后每个服务启动时向中心化 Nacos 注册，调用方从 Nacos 动态查询地址并做客户端负载均衡。

**架构：**

```
区域A: user-service(10.0.1.5:8001)  ──注册──▶
区域B: user-service(10.0.2.5:8001)  ──注册──▶  中心 Nacos
                                                    ▲
group-service 调用 user-service 时 ──查询──────────┘
  → 返回 [10.0.1.5:8001, 10.0.2.5:8001]
  → 随机选一个调用（客户端负载均衡）
```

代码已实现在 `services/*/nacos_client.py`，Nacos 不可用时自动回退到环境变量。

**模拟跨区域部署（本地测试）：**

```bash
docker-compose -f docker-compose.multi-region.yml up -d
```

这会启动区域A（user/group/message）和区域B（connector/push/storage）两组服务，共享一个中心 Nacos。

**真实跨区域部署时：**
1. 在公网部署一个 Nacos，所有区域的服务 `NACOS_HOST` 指向它
2. 每个服务的 `SERVICE_HOST` 设置为该服务的实际可达 IP
3. 各区域分别启动对应的服务

---

### 方案二：Istio 服务网格（K8s 多集群）

适合纯云上 K8s 场景。服务发现由 K8s 控制面处理，跨集群流量通过 East-West Gateway 路由，自动 mTLS 加密，内置负载均衡、熔断、重试。

**架构：**

```
集群A（区域A）                    集群B（区域B）
  user-service    ◀──────────────▶  connector-service
  group-service      East-West       push-service
  message-service    Gateway(15443)  storage-service
       ↕ Istio sidecar proxy ↕
```

**一键部署两个集群：**

```bash
./k8s/deploy-multi-cluster.sh \
  --context-a <集群A的kubectl-context> \
  --context-b <集群B的kubectl-context> \
  --registry dockerhub \
  --hub-user <你的DockerHub用户名>
```

**前置要求：**
- 安装 [istioctl](https://istio.io/latest/docs/setup/getting-started/)
- 两个集群已配置好 kubeconfig context（`kubectl config get-contexts` 查看）
- 两个集群网络互通（East-West Gateway 端口 15443 可达）

**Istio 配置文件说明：**

| 文件 | 作用 |
|------|------|
| `k8s/istio/east-west-gateway.yaml` | 跨集群流量入口 |
| `k8s/istio/service-entries.yaml` | 注册远端集群的服务地址 |
| `k8s/istio/destination-rules.yaml` | 负载均衡策略 + 熔断规则 |
| `k8s/istio/virtual-services.yaml` | 流量路由 + 重试 + 超时 |
| `k8s/istio/peer-authentication.yaml` | 强制 mTLS 加密 |

**验证服务网格状态：**

```bash
istioctl --context=<集群A> proxy-status
istioctl --context=<集群B> proxy-status
```

---

### 注册账号

1. 打开应用首页，点击「Register」
2. 填写用户名、显示名、邮箱、密码
3. 注册成功后系统会发送验证邮件（如未配置 SMTP，可跳过验证直接登录）

> 如需邮件功能（验证邮箱、密码重置、离线通知），在 `.env` 中填写 SMTP 配置：
> ```
> SMTP_HOST=smtp.gmail.com
> SMTP_PORT=587
> SMTP_USER=your@email.com
> SMTP_PASSWORD=your-password
> ```

### 创建聊天室

1. 登录后点击左上角「New Room」
2. 输入聊天室名称，点击「Create」

### 邀请好友

1. 选中一个聊天室
2. 在顶部输入框填写对方用户名，点击「Invite」
3. 对方登录后会在通知铃铛处看到邀请，接受后加入聊天室

### 发送消息

在聊天室底部输入框输入内容，按 `Enter` 或点击发送按钮即可。消息会实时推送给房间内所有在线成员。

---

## Elasticsearch 集成方案

### 设计目标

为 IM 系统引入 Elasticsearch，实现消息全文搜索、用户模糊搜索、房间名称搜索能力。当前系统消息存储在 ScyllaDB 中，仅支持按 `room_id` 精确查询，无法进行跨房间内容检索；用户搜索依赖 MySQL `LIKE` 查询，性能和功能均有限。

### 架构设计

采用 **CQRS（命令查询职责分离）+ Kafka 异步同步** 模式：

- **写路径**：消息仍写入 ScyllaDB（主存储），用户/房间仍写入 MySQL（主存储）
- **读路径**：搜索请求走 Elasticsearch，常规消息查询仍走 ScyllaDB
- **数据同步**：通过 Kafka 事件异步同步到 ES，保证最终一致性

```
写路径（不变）：
  message-service → ScyllaDB（主存储）→ Kafka msg_sent
  user-service    → MySQL（主存储）    → Kafka user_updated
  group-service   → MySQL（主存储）    → Kafka room_updated

同步路径（新增）：
  search-service 消费 Kafka → 写入 Elasticsearch

读路径（新增）：
  前端 → APISIX → search-service → Elasticsearch
```

### Elasticsearch 索引设计

#### im_messages 索引

```json
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "ik_smart_analyzer": {
          "type": "custom",
          "tokenizer": "ik_smart"
        },
        "ik_max_word_analyzer": {
          "type": "custom",
          "tokenizer": "ik_max_word"
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "message_id": { "type": "keyword" },
      "room_id":    { "type": "integer" },
      "sender_id":  { "type": "integer" },
      "content":    {
        "type": "text",
        "analyzer": "ik_max_word_analyzer",
        "search_analyzer": "ik_smart_analyzer",
        "fields": {
          "keyword": { "type": "keyword", "ignore_above": 256 }
        }
      },
      "created_at": { "type": "date" }
    }
  }
}
```

**设计说明：**
- `content` 使用 `ik_max_word` 索引分词（最细粒度），`ik_smart` 搜索分词（智能切分），兼顾召回率和精确度
- `room_id` 为 integer 类型，支持按房间过滤
- `message_id` 为 keyword 类型，用于精确定位和去重
- `created_at` 为 date 类型，支持时间范围过滤和排序

#### im_users 索引

```json
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "prefix_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "edge_ngram_filter"]
        }
      },
      "filter": {
        "edge_ngram_filter": {
          "type": "edge_ngram",
          "min_gram": 1,
          "max_gram": 20
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "user_id":     { "type": "keyword" },
      "username":    {
        "type": "text",
        "analyzer": "prefix_analyzer",
        "search_analyzer": "standard",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "displayname": {
        "type": "text",
        "analyzer": "prefix_analyzer",
        "search_analyzer": "standard",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "email":       { "type": "keyword" },
      "avatar":      { "type": "keyword" },
      "is_active":   { "type": "boolean" }
    }
  }
}
```

**设计说明：**
- `username` / `displayname` 使用 `edge_ngram` 分词器，支持前缀匹配（输入"张"即可匹配"张三"）
- 同时保留 `keyword` 子字段，支持精确匹配和排序
- `email` 为 keyword 类型，支持精确查找

#### im_rooms 索引

```json
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1
  },
  "mappings": {
    "properties": {
      "room_id":    { "type": "keyword" },
      "name":       {
        "type": "text",
        "analyzer": "ik_max_word",
        "search_analyzer": "ik_smart"
      },
      "creator_id": { "type": "integer" },
      "created_at": { "type": "date" }
    }
  }
}
```

### 数据同步策略

#### 消息同步（复用现有 Kafka topic）

search-service 作为新的消费者组消费 `msg_sent` topic：

```python
# search-service/services/kafka_consumer.py
async def consume_messages():
    consumer = AIOKafkaConsumer(
        "msg_sent",
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        group_id="search-service"
    )
    async for msg in consumer:
        data = msg.value
        await es.index(
            index="im_messages",
            id=data["message_id"],
            body={
                "message_id": data["message_id"],
                "room_id": data["room_id"],
                "sender_id": data["sender_id"],
                "content": data["content"],
                "created_at": data["created_at"]
            }
        )
```

**优势：** 复用现有 `msg_sent` topic，无需修改 message-service 代码。Kafka 消费者组隔离，不影响 connector-service 和 push-service。

#### 用户同步（新增 Kafka topic）

user-service 在用户注册和更新时发布 `user_updated` 事件：

```python
# user-service/main.py 新增发布逻辑
@app.post("/api/user/register")
async def register(user: UserCreate, db: Session = Depends(get_db)):
    # ... 原有注册逻辑 ...
    await publish("user_updated", {
        "type": "user_updated",
        "user_id": new_user.id,
        "username": new_user.username,
        "displayname": new_user.displayname,
        "email": new_user.email,
        "avatar": new_user.avatar,
        "is_active": new_user.is_active
    })

@app.put("/api/user/me")
async def update_profile(user_update: UserUpdate, ...):
    # ... 原有更新逻辑 ...
    await publish("user_updated", {
        "type": "user_updated",
        "user_id": current_user.id,
        "username": current_user.username,
        "displayname": current_user.displayname,
        "email": current_user.email,
        "avatar": current_user.avatar,
        "is_active": current_user.is_active
    })
```

#### 房间同步（新增 Kafka topic）

group-service 在房间创建和更新时发布 `room_updated` 事件：

```python
# group-service/main.py 新增发布逻辑
@app.post("/api/group/rooms")
async def create_room(room: RoomCreate, ...):
    # ... 原有创建逻辑 ...
    await publish("room_updated", {
        "type": "room_updated",
        "room_id": new_room.id,
        "name": new_room.name,
        "creator_id": new_room.creator_id,
        "created_at": new_room.created_at.isoformat()
    })
```

### 搜索 API 设计

#### 消息搜索

```
GET /api/search/messages?q=关键词&room_id=可选&from=0&size=20
```

**请求参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| q | string | 是 | 搜索关键词 |
| room_id | int | 否 | 限定房间范围 |
| from | int | 否 | 分页偏移，默认 0 |
| size | int | 否 | 每页条数，默认 20，最大 100 |

**响应示例：**

```json
{
  "total": 42,
  "from": 0,
  "size": 20,
  "results": [
    {
      "message_id": "uuid-xxx",
      "room_id": 1,
      "sender_id": 5,
      "content": "今天<em>天气</em>真好",
      "created_at": "2026-04-09T10:30:00Z",
      "sender": {
        "id": 5,
        "username": "zhangsan",
        "displayname": "张三",
        "avatar": "https://cdn.4chat.example.com/static/avatars/uploads/xxx.png"
      }
    }
  ]
}
```

**ES 查询构建：**

```python
body = {
    "query": {
        "bool": {
            "must": [
                {
                    "match": {
                        "content": {
                            "query": keyword,
                            "analyzer": "ik_smart"
                        }
                    }
                }
            ],
            "filter": []
        }
    },
    "highlight": {
        "pre_tags": ["<em>"],
        "post_tags": ["</em>"],
        "fields": {
            "content": {}
        }
    },
    "sort": [
        "_score",
        {"created_at": {"order": "desc"}}
    ],
    "from": from_offset,
    "size": page_size
}

if room_id:
    body["query"]["bool"]["filter"].append({"term": {"room_id": room_id}})
```

#### 用户搜索（增强）

```
GET /api/search/users?q=关键词&from=0&size=20
```

替代原有 `/api/user/search`，支持前缀匹配和模糊搜索。

#### 房间搜索

```
GET /api/search/rooms?q=关键词&from=0&size=20
```

### search-service 依赖

```
search-service: Elasticsearch, Kafka, Nacos
```

### Docker Compose 配置

在 `docker-compose.yml` 中新增：

```yaml
elasticsearch:
  image: elasticsearch:8.17.0
  container_name: im-elasticsearch
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false
    - ES_JAVA_OPTS=-Xms512m -Xmx512m
  ports:
    - "9200:9200"
  volumes:
    - es_data:/usr/share/elasticsearch/data
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 10

kibana:
  image: kibana:8.17.0
  container_name: im-kibana
  depends_on:
    elasticsearch:
      condition: service_healthy
  ports:
    - "5601:5601"
  environment:
    - ELASTICSEARCH_HOSTS=http://elasticsearch:9200

search-service:
  build: ./services/search-service
  container_name: im-search-service
  ports:
    - "8007:8007"
  depends_on:
    elasticsearch:
      condition: service_healthy
    kafka:
      condition: service_healthy
    nacos:
      condition: service_healthy
  environment:
    ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    KAFKA_BOOTSTRAP_SERVERS: kafka:9092
    NACOS_HOST: nacos
    NACOS_PORT: "8848"
    SERVICE_HOST: search-service
    SERVICE_PORT: "8007"
    SECRET_KEY: "your-secret-key-change-in-production"
    ACCESS_SECRET_KEY: "your-secret-key-change-in-production"
  restart: on-failure

volumes:
  es_data:
```

### APISIX 路由新增

在 `gateway/apisix.yaml` 中新增：

```yaml
- id: search-service-route
  uri: /api/search/*
  upstream:
    nodes:
      "search-service:8007": 1
  plugins:
    cors:
      allow_origins: "*"
      allow_methods: "GET,POST,PUT,DELETE,OPTIONS"
      allow_headers: "*"
```

### Elasticsearch 高可用部署

| 场景 | 节点数 | 配置 |
|------|--------|------|
| 开发/测试 | 1 节点 | `discovery.type=single-node` |
| 生产（小规模） | 3 节点 | 3 master+data 混合节点，2 副本 |
| 生产（大规模） | 5+ 节点 | 3 专用 master + N data 节点，按需扩容 |

**K8s 高可用 ES 部署：**

```bash
kubectl apply -f k8s/middleware/elasticsearch.yaml
```

**数据一致性保障：**

1. **最终一致性**：Kafka 消费者保证 at-least-once 投递，ES 写入使用 `id` 字段去重
2. **全量重建**：提供 `/api/search/reindex` 管理接口，从 ScyllaDB/MySQL 全量重建索引
3. **监控告警**：通过 Kibana 监控索引健康状态和同步延迟

---

## CDN 集成方案

### 设计目标

为 IM 系统引入 CDN，加速静态资源、头像、文件的分发，降低源站压力，提升全球用户访问速度。当前所有文件由 storage-service 直接提供，随着用户量增长将面临带宽和延迟瓶颈。

### 架构设计

```
用户请求
  │
  ▼
CDN 边缘节点（就近响应）
  │
  ├── 缓存命中 → 直接返回（毫秒级）
  │
  └── 缓存未命中 → 回源
        │
        ▼
      源站（Origin）
        ├── 前端 Nginx     → 静态资源（JS/CSS/HTML）
        └── storage-service → 头像/文件
```

### CDN 覆盖范围

| 资源类型 | CDN 域名 | 源站路径 | 缓存策略 |
|---------|---------|---------|---------|
| 前端静态资源 | `app.4chat.example.com` | 前端 Nginx | 哈希文件1年，index.html 不缓存 |
| 默认头像 | `cdn.4chat.example.com` | storage-service | 1天（不常变化） |
| 用户上传头像 | `cdn.4chat.example.com` | storage-service | 1小时（可能更新） |
| 聊天文件/图片 | `cdn.4chat.example.com` | storage-service | 7天（未来扩展） |

### 缓存规则设计

#### 前端静态资源

```nginx
# 前端 Nginx 添加缓存头
location /static/ {
    # 带哈希的静态文件（如 main.a1b2c3.js）
    if ($uri ~* \.[a-f0-9]{8,}\.(js|css|png|jpg|svg|ico|woff2)$) {
        add_header Cache-Control "public, max-age=31536000, immutable";
    }
}

location /index.html {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
}
```

#### 头像和文件

```python
# storage-service/main.py 修改响应头

@app.get("/api/storage/static/avatars/default/{filename}")
async def serve_default_avatar(filename: str):
    # 默认头像：缓存1天
    return FileResponse(
        path=os.path.join(DEFAULT_DIR, filename),
        headers={"Cache-Control": "public, max-age=86400"}
    )

@app.get("/api/storage/static/avatars/uploads/{filename}")
async def serve_uploaded_avatar(filename: str):
    # 上传头像：缓存1小时
    return FileResponse(
        path=os.path.join(UPLOAD_DIR, filename),
        headers={"Cache-Control": "public, max-age=3600"}
    )
```

### CDN 接入方式

#### 方式一：云服务商 CDN（推荐生产使用）

以阿里云 CDN 为例：

1. **添加加速域名**：`cdn.4chat.example.com` 和 `app.4chat.example.com`
2. **配置源站**：
   - `cdn.4chat.example.com` → 源站 `origin.4chat.example.com`（指向 storage-service）
   - `app.4chat.example.com` → 源站 `origin-app.4chat.example.com`（指向前端 Nginx）
3. **配置缓存规则**（在 CDN 控制台）：
   - `/static/avatars/default/*` → 缓存1天
   - `/static/avatars/uploads/*` → 缓存1小时
   - `/static/js/*`, `/static/css/*`, `/static/media/*` → 缓存1年
   - `/index.html` → 不缓存
4. **配置 HTTPS 证书**：上传 SSL 证书，开启 HTTPS
5. **DNS 解析**：将 CDN 域名 CNAME 到云服务商分配的 CDN 域名

**其他云服务商：**

| 云服务商 | CDN 产品 | 对应服务 |
|---------|---------|---------|
| 阿里云 | CDN | OSS + CDN |
| 腾讯云 | CDN | COS + CDN |
| AWS | CloudFront | S3 + CloudFront |
| 华为云 | CDN | OBS + CDN |

#### 方式二：自建 Nginx 缓存层（适合开发/内网环境）

在 APISIX 和 storage-service 之间增加 Nginx 缓存层：

```nginx
# cdn-proxy/nginx.conf
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=cdn_cache:100m
                 max_size=10g inactive=7d use_temp_path=off;

server {
    listen 80;
    server_name cdn.4chat.example.com;

    location /static/avatars/default/ {
        proxy_cache cdn_cache;
        proxy_cache_valid 200 1d;
        proxy_pass http://storage-service:8006;
        add_header X-Cache-Status $upstream_cache_status;
        add_header Cache-Control "public, max-age=86400";
    }

    location /static/avatars/uploads/ {
        proxy_cache cdn_cache;
        proxy_cache_valid 200 1h;
        proxy_pass http://storage-service:8006;
        add_header X-Cache-Status $upstream_cache_status;
        add_header Cache-Control "public, max-age=3600";
    }

    location /static/ {
        proxy_cache cdn_cache;
        proxy_cache_valid 200 7d;
        proxy_pass http://storage-service:8006;
        add_header X-Cache-Status $upstream_cache_status;
    }
}
```

**Docker Compose 配置：**

```yaml
cdn-proxy:
  image: nginx:stable-alpine
  container_name: im-cdn-proxy
  ports:
    - "8443:80"
  volumes:
    - ./cdn-proxy/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    - cdn_cache:/var/cache/nginx
  depends_on:
    - storage-service
  restart: on-failure

volumes:
  cdn_cache:
```

### 代码改造

#### storage-service 返回 CDN URL

```python
# storage-service/main.py

CDN_BASE_URL = os.environ.get("CDN_BASE_URL", "")

@app.post("/api/storage/upload-avatar")
async def upload_avatar(request: Request, file: UploadFile = File(...)):
    await get_current_user_id(request)
    ext = os.path.splitext(file.filename)[1] or ".png"
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = os.path.join(UPLOAD_DIR, filename)
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)

    if CDN_BASE_URL:
        url = f"{CDN_BASE_URL}/static/avatars/uploads/{filename}"
    else:
        url = f"/api/storage/static/avatars/uploads/{filename}"

    return {"url": url}
```

#### user-service 返回 CDN URL

```python
# user-service/main.py

CDN_BASE_URL = os.environ.get("CDN_BASE_URL", "")

def get_avatar_url(avatar_path: str) -> str:
    if not avatar_path:
        return avatar_path
    if CDN_BASE_URL and avatar_path.startswith("/api/storage/static/"):
        return avatar_path.replace("/api/storage/static/", f"{CDN_BASE_URL}/static/")
    return avatar_path
```

#### 环境变量

各服务新增环境变量：

```bash
CDN_BASE_URL=https://cdn.4chat.example.com   # 生产环境
CDN_BASE_URL=http://localhost:8443             # 本地开发（自建缓存代理）
CDN_BASE_URL=                                 # 不使用 CDN 时留空
```

### 头像更新与缓存失效

当用户更新头像时，旧文件名已变更（UUID 文件名），无需主动刷新 CDN 缓存：

1. 上传新头像 → 生成新 UUID 文件名 → 返回新 URL
2. 旧 URL 自然过期（TTL 到期后 CDN 不再缓存）
3. 用户信息更新 → Kafka `user_updated` 事件 → 前端刷新显示

如果未来需要主动刷新缓存，可通过云服务商 API 或 CDN 缓存刷新接口实现。

### CDN 监控指标

| 指标 | 说明 | 告警阈值 |
|------|------|---------|
| 命中率 | 缓存命中次数 / 总请求次数 | < 80% |
| 回源率 | 回源请求次数 / 总请求次数 | > 20% |
| 回源延迟 | 回源请求平均响应时间 | > 500ms |
| 流量带宽 | CDN 出流量 | 接近套餐上限 |
| 5xx 错误率 | CDN 和源站 5xx 比例 | > 1% |

---

## Celery 集成方案

### 设计目标

为 IM 系统引入 Celery 异步任务队列，将耗时的 I/O 操作从请求处理路径中剥离，提升 API 响应速度；同时引入 Celery Beat 定时调度器，替代现有基于 `threading.Thread` 的定时任务，提供更可靠的定时任务管理。

### 当前痛点

| 痛点 | 现状 | 影响 |
|------|------|------|
| 邮件发送阻塞请求 | `send_verification_email` / `send_password_reset_email` 在注册/重置密码接口中同步执行 | SMTP 超时导致 API 响应慢（3-10s） |
| 离线推送邮件阻塞消费 | push-service 中 `send_offline_notification` 同步执行 | SMTP 故障导致 Kafka 消费延迟 |
| 密钥轮换用线程 | `threading.Thread(daemon=True)` 运行 `rotate_keys_periodically` | 进程重启丢失调度状态，无法监控 |
| 无过期数据清理 | 过期 RefreshToken、旧头像文件无清理机制 | 数据库/磁盘持续膨胀 |
| 无 ES 全量重建 | 索引数据只能通过 Kafka 增量同步，无法全量重建 | ES 数据不一致时无修复手段 |

### 架构设计

```
                    ┌─────────────────────────────────────────┐
                    │           Redis (Broker + Backend)       │
                    │  ┌──────────┐  ┌──────────────────────┐ │
                    │  │  Broker   │  │  Result Backend      │ │
                    │  │ (任务队列) │  │ (celery-task-meta-*) │ │
                    │  └────┬─────┘  └──────────┬───────────┘ │
                    └───────┼────────────────────┼─────────────┘
                            │                    │
              ┌─────────────┼────────────────────┼─────────────┐
              │             ▼                    ▼             │
              │  ┌──────────────────────────────────────────┐  │
              │  │          Celery Worker 进程               │  │
              │  │                                          │  │
              │  │  Queue: emails      → 邮件发送任务        │  │
              │  │  Queue: default     → 通用异步任务        │  │
              │  │  Queue: search      → ES 索引操作任务     │  │
              │  │  Queue: maintenance → 数据清理定时任务     │  │
              │  └──────────────────────────────────────────┘  │
              │             ▲                    ▲             │
              │             │                    │             │
              │  ┌──────────┴──────┐  ┌─────────┴──────────┐  │
              │  │  Celery Beat    │  │  各微服务            │  │
              │  │  (定时调度器)    │  │  (任务生产者)        │  │
              │  └─────────────────┘  └────────────────────┘  │
              │             Celery 集群                        │
              └───────────────────────────────────────────────┘
```

**核心设计决策：**

- **Broker**：复用现有 Redis，无需新增中间件
- **Result Backend**：复用 Redis，任务结果存储在 `celery-task-meta-*` 键中
- **共享任务模块**：各微服务通过 `services/common/celery_app.py` 共享 Celery 配置和任务定义
- **Worker 部署**：独立 Worker 容器，按队列分流，可独立扩缩容

### 任务分类

#### 1. 邮件任务（Queue: `emails`）

| 任务名 | 触发方式 | 说明 |
|--------|---------|------|
| `send_verification_email_task` | user-service 注册时调用 | 发送邮箱验证邮件 |
| `send_password_reset_email_task` | user-service 请求重置时调用 | 发送密码重置邮件 |
| `send_offline_notification_task` | push-service 离线推送时调用 | 发送离线消息通知邮件 |

**改造前（同步阻塞）：**

```python
# user-service/services/auth_service.py
def send_verification_email(user: User):
    token = secrets.token_urlsafe(32)
    user.verification_token = token
    user.verification_expiry = datetime.utcnow() + timedelta(hours=24)
    link = f"{FRONTEND_URL}/verify-email?token={token}"
    body = f"<h1>Verify your email</h1><p><a href='{link}'>Verify Email</a></p>"
    return send_email(user.email, "Verify your email", body)  # 同步 SMTP，3-10s
```

**改造后（异步 Celery）：**

```python
# user-service/services/auth_service.py
def send_verification_email(user: User):
    token = secrets.token_urlsafe(32)
    user.verification_token = token
    user.verification_expiry = datetime.utcnow() + timedelta(hours=24)
    # 数据库先保存 token，再异步发邮件
    link = f"{FRONTEND_URL}/verify-email?token={token}"
    body = f"<h1>Verify your email</h1><p><a href='{link}'>Verify Email</a></p>"
    send_verification_email_task.delay(user.email, "Verify your email", body)
    return True  # 立即返回，邮件后台发送
```

```python
# services/common/celery_tasks.py
@celery_app.task(queue="emails", bind=True, max_retries=3, default_retry_delay=60)
def send_verification_email_task(self, to_email, subject, body):
    try:
        msg = MIMEMultipart()
        msg["From"] = SMTP_USER
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "html"))
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)
        server.quit()
    except Exception as exc:
        raise self.retry(exc=exc)
```

#### 2. 搜索索引任务（Queue: `search`）

| 任务名 | 触发方式 | 说明 |
|--------|---------|------|
| `reindex_messages_task` | 管理接口手动触发 | 从 ScyllaDB 全量重建消息索引 |
| `reindex_users_task` | 管理接口手动触发 | 从 MySQL 全量重建用户索引 |
| `reindex_rooms_task` | 管理接口手动触发 | 从 MySQL 全量重建房间索引 |

**全量重建索引示例：**

```python
@celery_app.task(queue="search", bind=True)
def reindex_messages_task(self):
    from cassandra.cluster import Cluster
    from database import MESSAGES_INDEX, MESSAGES_MAPPING

    es = get_es_client()
    # 删除旧索引并重建
    if es.indices.exists(index=MESSAGES_INDEX):
        es.indices.delete(index=MESSAGES_INDEX)
    es.indices.create(index=MESSAGES_INDEX, body=MESSAGES_MAPPING)

    # 从 ScyllaDB 批量读取并写入 ES
    cluster = Cluster(SCYLLA_HOSTS, port=SCYLLA_PORT)
    session = cluster.connect(SCYLLA_KEYSPACE)
    rows = session.execute("SELECT id, room_id, sender_id, content, created_at FROM messages")

    bulk_body = []
    for row in rows:
        bulk_body.append({"index": {"_index": MESSAGES_INDEX, "_id": str(row.id)}})
        bulk_body.append({
            "message_id": str(row.id),
            "room_id": row.room_id,
            "sender_id": row.sender_id,
            "content": row.content,
            "created_at": row.created_at.isoformat() if row.created_at else None
        })
        if len(bulk_body) >= 2000:  # 每 1000 条批量提交
            es.bulk(body=bulk_body)
            bulk_body = []
    if bulk_body:
        es.bulk(body=bulk_body)

    cluster.shutdown()
    return {"status": "completed", "index": MESSAGES_INDEX}
```

#### 3. 定时任务（Celery Beat）

| 任务名 | 调度周期 | 说明 |
|--------|---------|------|
| `cleanup_expired_tokens` | 每天凌晨 3:00 | 清理过期 RefreshToken |
| `rotate_jwt_keys` | 每 24 小时 | JWT 密钥轮换（替代 threading.Thread） |
| `cleanup_orphan_avatars` | 每周日凌晨 4:00 | 清理无引用的旧头像文件 |
| `es_index_health_check` | 每 30 分钟 | 检查 ES 索引健康状态并告警 |

**Beat 调度配置：**

```python
celery_app.conf.beat_schedule = {
    "cleanup-expired-tokens": {
        "task": "services.common.celery_tasks.cleanup_expired_tokens",
        "schedule": crontab(hour=3, minute=0),
    },
    "rotate-jwt-keys": {
        "task": "services.common.celery_tasks.rotate_jwt_keys",
        "schedule": crontab(hour="*/24"),
    },
    "cleanup-orphan-avatars": {
        "task": "services.common.celery_tasks.cleanup_orphan_avatars",
        "schedule": crontab(day_of_week=0, hour=4, minute=0),
    },
    "es-index-health-check": {
        "task": "services.common.celery_tasks.es_index_health_check",
        "schedule": crontab(minute="*/30"),
    },
}
```

**定时任务示例：**

```python
@celery_app.task(queue="maintenance")
def cleanup_expired_tokens():
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from datetime import datetime

    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    db = Session()
    try:
        result = db.query(RefreshToken).filter(
            RefreshToken.expires_at < datetime.utcnow()
        ).delete()
        db.commit()
        return {"deleted_count": result}
    finally:
        db.close()

@celery_app.task(queue="maintenance")
def rotate_jwt_keys():
    kms = KeyManagementService()
    for kt in ("access", "refresh"):
        kms.delete_old_keys(kt)
        kms.deactivate_old_keys(kt)
        kms.generate_new_key(kt)
    return {"status": "rotated", "timestamp": datetime.utcnow().isoformat()}
```

### 代码结构

```
services/common/
├── celery_app.py          # Celery 实例配置（Broker、序列化、时区等）
├── celery_tasks.py        # 共享任务定义（邮件、索引重建、定时任务）
├── nacos_client.py        # 现有
└── ha_database.py         # 现有

services/user-service/
├── main.py                # 调用 send_verification_email_task.delay() 替代同步邮件
├── services/auth_service.py  # 移除 send_email() 同步实现，改为调用 Celery 任务
└── ...

services/push-service/
├── services/push_handler.py  # 调用 send_offline_notification_task.delay() 替代同步邮件
└── ...

services/search-service/
├── main.py                # 新增 /api/search/reindex 管理接口，触发全量重建
└── ...
```

### celery_app.py 核心配置

```python
# services/common/celery_app.py
from celery import Celery
import os

CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://redis:6379/1")
CELERY_RESULT_BACKEND = os.environ.get("CELERY_RESULT_BACKEND", "redis://redis:6379/2")

celery_app = Celery(
    "4chat",
    broker=CELERY_BROKER_URL,
    backend=CELERY_RESULT_BACKEND,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_routes={
        "services.common.celery_tasks.send_*": {"queue": "emails"},
        "services.common.celery_tasks.reindex_*": {"queue": "search"},
        "services.common.celery_tasks.cleanup_*": {"queue": "maintenance"},
        "services.common.celery_tasks.rotate_*": {"queue": "maintenance"},
        "services.common.celery_tasks.es_*": {"queue": "search"},
    },
)
```

**设计说明：**
- Broker 使用 Redis db1（与业务缓存 db0 隔离）
- Result Backend 使用 Redis db2（与 Broker 隔离）
- `task_acks_late=True`：任务执行完毕后才确认，避免 Worker 崩溃导致任务丢失
- `worker_prefetch_multiplier=1`：每次只预取一个任务，避免长任务阻塞短任务
- 按队列路由：邮件任务、搜索任务、维护任务分队列执行，互不影响

### Docker Compose 配置

在 `docker-compose.yml` 中新增：

```yaml
celery-worker-emails:
    build: ./services/worker
    container_name: im-celery-worker-emails
    depends_on:
      redis:
        condition: service_healthy
    environment:
      CELERY_BROKER_URL: redis://redis:6379/1
      CELERY_RESULT_BACKEND: redis://redis:6379/2
      SMTP_SERVER: smtp.gmail.com
      SMTP_PORT: "587"
      SMTP_USER: ""
      SMTP_PASSWORD: ""
      FRONTEND_URL: http://localhost:3000
    command: celery -A services.common.celery_app worker -Q emails --loglevel=info -c 4
    restart: on-failure

  celery-worker-default:
    build: ./services/worker
    container_name: im-celery-worker-default
    depends_on:
      redis:
        condition: service_healthy
    environment:
      CELERY_BROKER_URL: redis://redis:6379/1
      CELERY_RESULT_BACKEND: redis://redis:6379/2
      DATABASE_URL: mysql+pymysql://root:root123@mysql:3306/im_user
      SCYLLA_HOSTS: scylladb
      SCYLLA_PORT: "9042"
      SCYLLA_KEYSPACE: im_message
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    command: celery -A services.common.celery_app worker -Q default,search,maintenance --loglevel=info -c 2
    restart: on-failure

  celery-beat:
    build: ./services/worker
    container_name: im-celery-beat
    depends_on:
      redis:
        condition: service_healthy
    environment:
      CELERY_BROKER_URL: redis://redis:6379/1
      CELERY_RESULT_BACKEND: redis://redis:6379/2
      DATABASE_URL: mysql+pymysql://root:root123@mysql:3306/im_user
    command: celery -A services.common.celery_app beat --loglevel=info
    restart: on-failure
```

### Worker Dockerfile

```dockerfile
# services/worker/Dockerfile
FROM python:3.11.15
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
```

```txt
# services/worker/requirements.txt
celery[redis]>=5.4.0
redis
sqlalchemy
pymysql
cryptography
python-jose[cryptography]
elasticsearch>=8.0.0,<9.0.0
cassandra-driver
```

### 管理接口

在 search-service 中新增全量重建接口：

```
POST /api/search/reindex/messages    → 触发 reindex_messages_task
POST /api/search/reindex/users       → 触发 reindex_users_task
POST /api/search/reindex/rooms       → 触发 reindex_rooms_task
GET  /api/search/reindex/status/{task_id}  → 查询重建进度
```

**响应示例：**

```json
{
  "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "PENDING",
  "message": "Reindex task submitted"
}
```

### Celery 监控（Flower）

```yaml
celery-flower:
    image: mher/flower:2.0
    container_name: im-celery-flower
    depends_on:
      redis:
        condition: service_healthy
    ports:
      - "5555:5555"
    environment:
      - CELERY_BROKER_URL=redis://redis:6379/1
      - FLOWER_PORT=5555
    restart: on-failure
```

访问 `http://localhost:5555` 查看：
- Worker 状态和负载
- 任务执行历史和成功率
- 队列深度和消息积压
- 定时任务调度状态

### 各服务改造清单

| 服务 | 改造内容 |
|------|---------|
| user-service | `send_verification_email` / `send_password_reset_email` 改为调用 Celery 任务；移除 `threading.Thread` 密钥轮换，改由 Celery Beat 调度 |
| push-service | `send_offline_notification` 改为调用 Celery 任务 |
| search-service | 新增 `/api/search/reindex/*` 管理接口，触发全量重建任务 |
| 新增 worker 服务 | 独立 Celery Worker + Beat 容器 |

### Celery 高可用部署

| 场景 | Worker 配置 | Beat 配置 |
|------|------------|-----------|
| 开发/测试 | 1 Worker（所有队列） | 1 Beat |
| 生产（小规模） | 2 Worker（1 emails + 1 default/search/maintenance） | 1 Beat |
| 生产（大规模） | 3+ Worker（1 emails + 1 search + 1+ default/maintenance） | 1 Beat（K8s Leader Election 防重复） |

**K8s 部署注意事项：**
- Beat 只能运行 1 个实例，使用 `replicas: 1` + `podDisruptionBudget` 保证可用性
- Worker 可按队列独立扩缩容，使用 HPA 根据队列深度自动伸缩
- 使用 `celery -A app inspect active` 监控 Worker 状态

---

## 常见问题

**Q: 启动后页面空白？**

等待约 1 分钟让所有服务完全启动，然后刷新页面。用 `docker-compose ps` 或 `kubectl get pods` 检查服务状态。

**Q: 某个服务一直重启？**

通常是依赖服务（MySQL/Kafka）还没准备好。等待 1-2 分钟后会自动恢复，所有服务都配置了自动重启。

**Q: 如何查看服务日志？**

```bash
# Docker Compose
docker-compose logs -f user-service
docker-compose logs -f

# K8s
kubectl logs -f deployment/user-service
```

**Q: 端口冲突怎么办？**

在 `docker-compose.yml` 中修改端口映射，例如将 `"3000:3000"` 改为 `"3001:3000"`，然后访问 http://localhost:3001。

**Q: K8s 部署后无法访问？**

确认 minikube 正在运行，并用 `minikube ip` 获取正确的 IP 地址。NodePort 端口为前端 30000、网关 30080。

**WSL 环境下 Windows 浏览器访问：**

```bash
./k8s/forward-ports.sh start
```

然后访问 http://localhost:13000

**Q: minikube 中 Kafka 启动失败？**

**现象：** Kafka pod CrashLoopBackOff，日志显示 `port is deprecated`。

**原因：** K8s 自动注入 `KAFKA_PORT` 环境变量（因为有名为 `kafka` 的 Service），导致 Kafka 启动脚本检测到废弃配置而退出。

**解决方案：** 已在 `k8s/middleware/kafka.yaml` 中添加 `enableServiceLinks: false` 禁用自动注入。

**Q: Nacos 启动失败？**

**现象：** Nacos v3 报错 `NACOS_AUTH_TOKEN must be set`。

**解决方案：** 已在 `k8s/middleware/nacos.yaml` 中添加 Base64 编码的 `NACOS_AUTH_TOKEN`，并使用 tcpSocket readiness probe。

**Q: message-service 启动失败？**

**现象：** 报错 `cassandra.UnresolvableContactPoints`。

**原因：** ScyllaDB 未部署。

**解决方案：** 运行 `kubectl apply -f k8s/middleware/scylladb.yaml`，或使用 `./k8s/deploy.sh` 自动部署。

**Q: minikube 无法拉取镜像？**

**现象：** ImagePullBackOff，网络超时。

**解决方案：** deploy.sh 已实现自动回退机制：先尝试 pull，失败则从宿主机 Docker load 镜像。确保宿主机已有相关镜像。

---

## WSL2 环境下的已知问题与解决方案

> 适用于：在 WSL2（非 Docker Desktop）中使用 Docker，Windows 浏览器无法访问服务的情况。

### 问题：Windows 浏览器访问 localhost 超时

**现象：** WSL 内 `curl localhost:3000` 正常，Windows 浏览器访问 `localhost:3000` 超时（ERR_CONNECTION_TIMED_OUT）。

**根本原因：Hairpin NAT 问题**

WSL2 mirror 模式下，Windows 发来的请求源 IP 和目标 IP 都是同一个（如 `192.168.123.50`），Docker 容器回包时内核判断这是异常连接，立即发送 RST 重置。

抓包可以看到：
```
客户端 SYN  → 192.168.123.50:3000
DNAT转发    → 172.18.0.x:3000  
容器回复    SYN-ACK
立刻        RST  ← 连接被重置
```

**解决方案：socat 端口转发**

socat 监听在不同端口（原端口前加 `1`），把流量从 `127.0.0.1` 转发到容器 IP，绕开 hairpin 问题：

```bash
# 安装 socat
sudo apt install socat

# 使用项目提供的脚本
./forward-ports.sh start

# 停止转发
./forward-ports.sh stop
```

| 服务 | Windows 访问地址 |
|------|-----------------|
| 前端 | http://localhost:13000 |
| APISIX 网关 | http://localhost:8080（nginx 内部代理） |
| Nacos 控制台 | http://localhost:18848 |
| user-service | http://localhost:18001 |
| group-service | http://localhost:18002 |
| message-service | http://localhost:18003 |
| connector-service | http://localhost:18004 |
| push-service | http://localhost:18005 |
| storage-service | http://localhost:18006 |

> **注意：** 每次重启 WSL 或重启 Docker 容器后，需要重新运行 `./forward-ports.sh start`。

---

### 问题：APISIX 端口冲突（8080 被占用）

**现象：** socat 无法绑定 `0.0.0.0:8080`，报 `Address already in use`。

**原因：** Linux 内核规定，`0.0.0.0` 绑定会覆盖所有地址包括 `127.0.0.1`，因此即使 Docker 只绑了 `127.0.0.1:8080`，socat 仍无法绑 `0.0.0.0:8080`。

**解决方案：** 前端 nginx 内部代理 `/api/` 和 `/ws/` 到 APISIX，前端代码使用相对路径，Windows 只需访问 `localhost:13000`，无需直接访问 8080。

---

### 问题：APISIX 启动报错

**现象：**
```
Error: config.yaml does not contain 'role: data_plane'. Deployment role must be set to 'data_plane' for standalone mode.
```

**原因：** APISIX 3.x 版本要求在 standalone 模式下显式声明 `role: data_plane`。

**解决方案：** 在 `config/apisix/config.yaml` 中确认包含：
```yaml
deployment:
  role: data_plane
  role_data_plane:
    config_provider: yaml
```

---

### 问题：connector-service / push-service 启动报 SyntaxError

**现象：**
```
File "/usr/local/lib/python3.11/site-packages/jose.py", line 546
    print decrypt(...)
SyntaxError: Missing parentheses in call to 'print'
```

**原因：** 安装了错误的 `jose` 包（Python 2 时代的旧版本），应安装 `python-jose`。

**解决方案：** 确认 `requirements.txt` 中使用的是 `python-jose` 而非 `jose`：
```
python-jose[cryptography]
```

---

### 问题：push-service / message-service 启动报 SQLAlchemy URL 解析错误

**现象：**
```
sqlalchemy.exc.ArgumentError: Could not parse SQLAlchemy URL from given URL string
```

**原因：** `DATABASE_URL` 环境变量未设置或格式错误，`ha_database.py` 在 module 级别调用 `create_engine()` 导致导入时就报错。

**解决方案：** 确认 `.env` 文件中 `DATABASE_URL` 格式正确：
```
DATABASE_URL=mysql+pymysql://root:root123@mysql:3306/im_user
```
