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
- [方案四：Kubernetes 云服务中间件](#方案四kubernetes-云服务中间件)
- [使用说明](#使用说明)
- [常见问题](#常见问题)

---

## 项目功能

- 用户注册 / 登录 / 邮箱验证 / 密码重置
- 好友申请与管理
- 创建聊天室、邀请好友加入
- 实时消息收发（WebSocket）
- 头像上传与默认头像选择
- 离线消息邮件通知

---

## 技术架构

整个系统由 6 个后端微服务组成，通过 APISIX 网关统一对外提供服务。

```
浏览器
  │
  ▼
APISIX 网关 (localhost:8080)
  │
  ├── /api/user/*     → user-service      用户、登录、好友
  ├── /api/group/*    → group-service     聊天室、邀请
  ├── /api/message/*  → message-service   消息存储（ScyllaDB）
  ├── /ws/*           → connector-service WebSocket 实时连接
  └── /api/storage/*  → storage-service   头像文件
```

**中间件：**

| 组件 | 用途 |
|------|------|
| MySQL | 持久化存储用户、群组数据 |
| ScyllaDB | 消息存储（时序数据，高吞吐） |
| Redis | 在线状态缓存、用户信息缓存 |
| Kafka | 服务间异步消息传递 |
| Nacos | 服务注册与发现 |

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
| 头像文件 | 本地磁盘 / PV | 持久化 |
| 用户缓存 | Redis `user:{id}` | TTL 5分钟，加速查询 |
| 在线状态 | Redis `online_users` | Set，实时更新 |
| 消息事件 | Kafka `msg_sent` | 异步，消费后丢弃 |
| 消息记录 | ScyllaDB `im_message` | 时序存储，partition by room_id |
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
│   └── storage-service/   # 文件存储       (端口 8006)
├── gateway/
│   ├── apisix.yaml        # 路由配置
│   └── config.yaml        # APISIX 配置
├── k8s/
│   ├── middleware/        # MySQL/Redis/Kafka/Nacos K8s 配置
│   ├── services/          # 6个微服务 + 前端 K8s 配置
│   ├── gateway/           # APISIX K8s 配置
│   ├── overlays/cloud/    # Kustomize 云服务中间件 overlay
│   └── deploy.sh          # 一键部署脚本
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
| K8s 本地 minikube | 本地 K8s | 本地 registry 或 Docker Hub | 学习 K8s / 测试 |
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
