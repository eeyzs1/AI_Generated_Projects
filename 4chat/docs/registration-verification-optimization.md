# 用户注册验证流程优化方案

## 1. 背景与问题

### 旧流程

```
用户注册 → 立即写入 MySQL users 表（email_verified=False）
         → 生成 verification_token 存入 users 表
         → 发送验证邮件
         → 用户点击验证链接
         → 标记 email_verified=True
```

### 旧流程问题

| 问题 | 说明 |
|------|------|
| 未验证用户污染主表 | 假邮箱注册后数据永远留在 `users` 表，占用唯一约束和存储 |
| 唯一约束被占用 | 假邮箱占用了 username/email 唯一索引，真实用户无法注册 |
| 无自动清理 | `verification_token` / `verification_expiry` 存 MySQL，无过期清理机制 |
| 安全风险 | 用户注册即可获得数据库记录，即使邮箱是伪造的 |
| 验证时效过长 | 旧方案 token 有效期 24 小时，过长 |

## 2. 新流程设计

### 2.1 核心思路

**验证前不写主表，验证后才落库。**

注册时将用户信息暂存到 Redis（快速读取）+ MySQL 临时表（兜底持久化），用户点击验证链接后才写入 `users` 主表。

### 2.2 流程图

```
┌─────────────────────────────────────────────────────────────┐
│                        注册阶段                              │
│                                                             │
│  用户填写邮箱/手机号                                          │
│       │                                                     │
│       ▼                                                     │
│  后端检查 username/email 是否已存在于 users 表                  │
│       │                                                     │
│       ├── 已存在 → 返回 400 错误                               │
│       │                                                     │
│       └── 不存在 → 清理同 username/email 的旧 pending 记录      │
│                     │                                       │
│                     ▼                                       │
│              生成 token (secrets.token_urlsafe)              │
│                     │                                       │
│                     ├──▶ Redis SET reg:pending:{token}       │
│                     │    TTL = 30 分钟                       │
│                     │    value = JSON{用户信息 + expires_at}   │
│                     │                                       │
│                     ├──▶ MySQL pending_registrations 表       │
│                     │    单表、不分库                          │
│                     │    expires_at = now + 30min            │
│                     │                                       │
│                     └──▶ Celery 异步发送验证邮件               │
│                          链接: /verify-email?token=xxx       │
│                                                             │
│  返回: "Registration submitted. Please check your email..."  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                        验证阶段                              │
│                                                             │
│  用户点击邮件中的验证链接                                       │
│       │                                                     │
│       ▼                                                     │
│  后端收到 GET /api/user/verify-email?token=xxx               │
│       │                                                     │
│       ├── 1. 先查 Redis reg:pending:{token}                  │
│       │      │                                              │
│       │      ├── 存在且未过期 → 取出用户数据                    │
│       │      └── 不存在/过期 → 进入步骤 2                      │
│       │                                                     │
│       ├── 2. 查 MySQL pending_registrations 表（兜底）         │
│       │      │                                              │
│       │      ├── 存在且未过期 → 取出用户数据                    │
│       │      └── 不存在/已过期 → 返回 404 "链接已过期"          │
│       │                                                     │
│       ├── 3. 二次校验 username/email 在 users 表中是否被占用    │
│       │      │                                              │
│       │      └── 被占用 → 返回 409 冲突                       │
│       │                                                     │
│       ├── 4. 写入 MySQL users 表                              │
│       │      email_verified = True                           │
│       │      is_active = True                                │
│       │                                                     │
│       ├── 5. 删除 Redis 临时 key                              │
│       │                                                     │
│       ├── 6. 删除 MySQL pending_registrations 记录             │
│       │                                                     │
│       └── 7. 发布 Kafka user_updated 事件                     │
│                                                             │
│  返回: "Email verified successfully. You can now login."     │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 极端情况处理

#### Redis 宕机

```
注册时 Redis 写入失败:
  → 日志记录 warning
  → MySQL 临时表已写入，不影响注册
  → 验证时直接走 MySQL 兜底

验证时 Redis 不可用:
  → Redis 读取异常，自动 fallback 到 MySQL 临时表
  → 用户仍可正常完成验证
```

#### MySQL 临时表也宕机（双重故障）

```
注册时 MySQL 写入失败:
  → 注册接口直接报错，用户需重试
  → 保证数据一致性，宁可让用户重试也不丢数据

验证时 Redis 和 MySQL 都不可用:
  → 返回 500 错误，提示用户稍后重试
  → 验证链接仍在邮件中，用户可稍后再次点击
```

#### 并发注册同一 username/email

```
两个请求同时注册同一 username:
  → pending_registrations 表有 UNIQUE 约束
  → 第二个请求会触发 IntegrityError
  → 注册接口先删除旧 pending 记录再创建新的，避免冲突

验证时 username 已被占用:
  → finalize_registration 二次校验
  → 返回 409 "Username already registered"
```

## 3. 数据存储设计

### 3.1 Redis 临时存储

```
Key:    reg:pending:{token}
TTL:    30 分钟 (1800 秒)
Value:  JSON {
          "token": "xxx",
          "username": "zhangsan",
          "displayname": "张三",
          "email": "zhangsan@example.com",
          "password_hash": "$pbkdf2-sha256$...",
          "avatar": "/api/storage/static/avatars/xxx.png",
          "expires_at": "2026-04-10T10:30:00"
        }
```

### 3.2 MySQL 临时表

```sql
CREATE TABLE pending_registrations (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    token       VARCHAR(255) NOT NULL UNIQUE,   -- 验证 token
    username    VARCHAR(50)  NOT NULL UNIQUE,   -- 用户名（唯一约束防并发）
    displayname VARCHAR(50)  NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,   -- 邮箱（唯一约束防并发）
    password_hash VARCHAR(255) NOT NULL,         -- 密码哈希
    avatar      VARCHAR(255) DEFAULT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at  TIMESTAMP NOT NULL,             -- 过期时间
    INDEX idx_token (token),
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**设计要点：**
- 单表、不分库 — 临时数据量小，无需分库分表
- username/email 设 UNIQUE — 防止并发注册冲突
- expires_at 索引 — 便于定时清理

### 3.3 users 表变更

`users` 表结构不变，但新注册用户写入时：
- `email_verified` 直接设为 `True`（因为验证通过才写入）
- `verification_token` / `verification_expiry` 字段保留但不再用于注册验证
- 这些字段仍可用于其他场景（如修改邮箱后的重新验证）

## 4. 定时清理

### 4.1 Redis 清理

Redis key 自动过期（TTL 机制），无需手动清理。

### 4.2 MySQL 临时表清理

通过 Celery Beat 定时任务清理过期记录：

```python
# 每 30 分钟执行一次
@celery_app.task(queue="maintenance")
def cleanup_expired_pending_registrations():
    DELETE FROM pending_registrations WHERE expires_at < NOW()
```

### 4.3 调度配置

```python
beat_schedule = {
    "cleanup-expired-pending-registrations": {
        "task": "cleanup_expired_pending_registrations",
        "schedule": crontab(minute="*/30"),  # 每 30 分钟
    },
}
```

## 5. API 变更

### 5.1 POST /api/user/register

**请求体：** 不变

```json
{
  "username": "zhangsan",
  "displayname": "张三",
  "email": "zhangsan@example.com",
  "password": "xxx",
  "avatar": "data:image/png;base64,..."
}
```

**响应变更：**

```json
// 旧
{"message": "Registration successful. Please check your email to verify your account."}

// 新
{"message": "Registration submitted. Please check your email to verify your account within 30 minutes."}
```

**行为变更：**
- 旧：立即写入 `users` 表，`email_verified=False`
- 新：写入 Redis + `pending_registrations` 表，不写 `users` 表

### 5.2 GET /api/user/verify-email?token=xxx

**响应变更：**

```
// 验证成功
200 {"message": "Email verified successfully. You can now login."}

// token 过期/无效（新增区分）
404 {"detail": "Invalid or expired verification link. Please register again."}

// username/email 已被占用（新增状态码）
409 {"detail": "Username already registered"}
```

**行为变更：**
- 旧：在 `users` 表中查找 `verification_token`，标记 `email_verified=True`
- 新：从 Redis/临时表取出数据，创建新用户到 `users` 表，删除临时数据

### 5.3 POST /api/user/login

**行为不变：** 仍检查 `email_verified` 字段，未验证用户无法登录。

## 6. 代码改动清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `services/user-service/models/pending_registration.py` | 新增 | MySQL 临时表 ORM 模型 |
| `services/user-service/services/auth_service.py` | 重写 | 新增 `store_pending_registration`、`retrieve_pending_registration`、`finalize_registration`；`send_verification_email` 改为 Redis+临时表双写 |
| `services/user-service/main.py` | 重写 | `register` 不再写 users 表；`verify-email` 改为验证时才创建用户 |
| `init.sql` | 新增 | `pending_registrations` 表 DDL |
| `services/common/celery_tasks.py` | 新增 | `cleanup_expired_pending_registrations` 定时清理任务 |
| `services/common/celery_app.py` | 新增 | Beat 调度配置 + task_routes |
| `frontend/src/Register.tsx` | 更新 | 提示信息改为"30 分钟内验证" |
| `frontend/src/VerifyEmail.tsx` | 更新 | 区分过期和已验证两种错误状态 |

## 7. 配置项

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `PENDING_REGISTRATION_TTL` | `1800` | 注册临时数据过期时间（秒），默认 30 分钟 |

## 8. 同步双写 vs 异步双写

### 选择：同步双写

注册时同步写入 Redis 和 MySQL 临时表，而非异步（通过 Kafka/Celery）。

**理由：**

| 维度 | 同步双写 | 异步双写 |
|------|---------|---------|
| 数据一致性 | ✅ 任一写入失败直接报错，用户重试 | ❌ 消息丢失时临时表无兜底数据 |
| 注册接口延迟 | ⚠️ 增加 ~5ms（MySQL 单表写入） | ✅ 无额外延迟 |
| 极端情况 | ✅ Redis 宕机时 MySQL 仍可兜底 | ❌ 消息丢失 + Redis 宕机 = 数据丢失 |
| 实现复杂度 | ✅ 简单，无消息丢失风险 | ⚠️ 需处理消息丢失、重复消费 |

注册接口本身就需要查 MySQL（检查 username/email 是否已存在），再写一条临时记录开销极小，同步双写的可靠性收益远大于 ~5ms 的延迟代价。
