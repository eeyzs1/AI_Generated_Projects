# 对话记录 hist8 — ScyllaDB 迁移 + README 完善

## 主要工作

### 1. message-service 迁移至 ScyllaDB

将消息存储从 MySQL（SQLAlchemy）完整迁移到 ScyllaDB（cassandra-driver）。

**修改文件：**

- `services/message-service/database.py`
  - 移除 SQLAlchemy，改用 cassandra-driver
  - 启动时自动创建 keyspace `im_message` 和 `messages` 表
  - 表结构：PRIMARY KEY (room_id, created_at, id)，按 room_id 分区，created_at DESC 排序

- `services/message-service/models/message.py`
  - 移除 SQLAlchemy ORM，改为 CQL 表结构注释说明

- `services/message-service/services/message_service.py`
  - 移除 SQLAlchemy Session 查询，改用 CQL 语句
  - `save_message`：生成 UUID，写入 ScyllaDB，返回 dict
  - `get_room_messages`：按 room_id 查询，返回 dict 列表

- `services/message-service/schemas/message.py`
  - `id` 字段从 `int` 改为 `UUID`

- `services/message-service/requirements.txt`
  - 移除 `sqlalchemy`、`pymysql`、`cryptography`
  - 新增 `cassandra-driver`

- `services/message-service/main.py`
  - 移除 `get_db` 依赖注入（SQLAlchemy Session）
  - 改用 `get_session()` 直接调用
  - startup 事件中调用 `get_session()` 初始化表结构
  - Kafka 事件中 message_id 改为 `str(msg["id"])`

---

### 2. 各 docker-compose 文件更新

**docker-compose.yml：**
- 新增 `scylladb` 服务（scylladb/scylla:5.4，单节点，限制 1 CPU / 512M 内存）
- message-service 依赖从 `mysql` 改为 `scylladb`
- 环境变量从 `DATABASE_URL` 改为 `SCYLLA_HOSTS / SCYLLA_PORT / SCYLLA_KEYSPACE`
- volumes 新增 `scylla_data`

**docker-compose.cloud.yml：**
- message-service 环境变量改为 ScyllaDB 相关变量（支持云托管 ScyllaDB）

**docker-compose.ha.yml：**
- 新增 `scylladb` 服务
- message-service 依赖和环境变量同步更新
- volumes 新增 `scylla_data`

---

### 3. K8s 配置更新

- 新建 `k8s/middleware/scylladb.yaml`：StatefulSet（1副本）+ Service，5Gi PVC，readinessProbe 用 cqlsh
- `k8s/services/message-service.yaml`：环境变量从 `DATABASE_URL` 改为 `SCYLLA_HOSTS / SCYLLA_PORT / SCYLLA_KEYSPACE`

---

### 4. init.sql 更新

移除 `im_message` 数据库（消息存储已迁移至 ScyllaDB，keyspace 由服务自动创建）。

现在只初始化：`im_user`、`im_group`、`im_storage`。

---

### 5. .env.example 更新

- 移除 `MYSQL_MESSAGE_URL`
- 新增 ScyllaDB 配置块：`SCYLLA_HOSTS`、`SCYLLA_PORT`、`SCYLLA_KEYSPACE`、`SCYLLA_USER`、`SCYLLA_PASSWORD`

---

### 6. README.md 更新

- 中间件表格：MySQL 说明改为"用户、群组数据"，新增 ScyllaDB 行
- 数据流说明：消息存储改为 ScyllaDB
- 数据存储分布表：消息记录改为 ScyllaDB
- 新增「微服务代码结构说明」章节，逐文件说明每个服务目录下各文件的功能

---

## 技术选型说明

| 对比项 | MySQL | ScyllaDB |
|--------|-------|----------|
| 实现语言 | C++ | C++（无 JVM） |
| 消息查询模式 | 全表扫描 + 索引 | 按 partition key 直接定位 |
| 写入性能 | 一般 | 极高（LSM Tree） |
| 时序数据支持 | 需要手动优化 | 原生支持（clustering key 排序） |
| 水平扩展 | 复杂（分库分表） | 原生支持 |
| GC 停顿 | 无（C++） | 无（C++） |

ScyllaDB 的 messages 表设计：
- partition key: `room_id` — 同一房间的消息在同一节点
- clustering key: `created_at DESC, id DESC` — 查询自动按时间倒序
- 无需 OFFSET，天然适合"加载最近 N 条"场景

---

## 其他问答

**Q: init.sql 初始化了哪些数据库？**
A: `im_user`、`im_group`、`im_storage`，共 3 个。`im_message` 已移除，由 ScyllaDB keyspace 替代。
