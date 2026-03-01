# 测试说明文档

## 测试概览

本项目使用 **pytest** 作为测试框架，测试覆盖后端所有核心模块：认证、聊天室、消息、WebSocket 服务层及 WebSocket 端点集成测试。

测试使用 **SQLite 内存数据库**，无需启动 MySQL 即可运行。

---

## 测试文件结构

```
chat_app/
├── pytest.ini                    # pytest 配置
└── tests/
    ├── __init__.py
    ├── conftest.py               # 共享 fixtures、数据库初始化、辅助函数
    ├── test_auth.py              # 注册、登录、JWT 认证测试
    ├── test_rooms.py             # 聊天室创建、列表、加入测试
    ├── test_messages.py          # 消息发送、获取测试
    ├── test_ws_service.py        # ConnectionManager 单元测试
    └── test_websocket.py         # WebSocket 端点集成测试
```

---

## 各测试文件说明

### `conftest.py`
- 创建 SQLite 测试数据库，session 级别建表，每个测试后清空数据
- 提供 `client` fixture（FastAPI TestClient，注入测试 DB）
- 提供 `db` fixture（直接访问测试 session）
- 提供辅助函数 `register_and_login()`、`auth_headers()`

### `test_auth.py` — 10 个测试
| 测试 | 说明 |
|------|------|
| `test_register_success` | 正常注册返回用户信息 |
| `test_register_duplicate_username` | 重复用户名返回 400 |
| `test_register_duplicate_email` | 重复邮箱返回 400 |
| `test_register_invalid_email` | 非法邮箱格式返回 422 |
| `test_login_success` | 正常登录返回 JWT token |
| `test_login_wrong_password` | 密码错误返回 401 |
| `test_login_nonexistent_user` | 用户不存在返回 401 |
| `test_get_me` | 携带有效 token 获取当前用户 |
| `test_get_me_no_token` | 无 token 返回 401 |
| `test_get_me_invalid_token` | 无效 token 返回 401 |

### `test_rooms.py` — 9 个测试
| 测试 | 说明 |
|------|------|
| `test_create_room_success` | 创建房间，创建者自动成为成员 |
| `test_create_room_duplicate_name` | 重复房间名返回 400 |
| `test_create_room_requires_auth` | 未认证返回 401 |
| `test_list_rooms` | 列出所有房间 |
| `test_list_rooms_empty` | 无房间时返回空列表 |
| `test_join_room_success` | 其他用户加入房间 |
| `test_join_room_already_member` | 重复加入幂等处理 |
| `test_join_nonexistent_room` | 加入不存在的房间返回 404 |

### `test_messages.py` — 7 个测试
| 测试 | 说明 |
|------|------|
| `test_send_message_success` | 成员发送消息成功 |
| `test_send_message_non_member` | 非成员发送消息返回 403 |
| `test_send_message_nonexistent_room` | 向不存在的房间发消息返回 404 |
| `test_send_message_requires_auth` | 未认证返回 401 |
| `test_get_messages_empty` | 无消息时返回空列表 |
| `test_get_messages_ordered` | 消息按时间升序排列 |
| `test_get_messages_non_member` | 非成员可查看消息（当前行为） |

### `test_ws_service.py` — 10 个单元测试
| 测试 | 说明 |
|------|------|
| `test_add_connection_registers_user` | 连接注册后用户在线 |
| `test_add_multiple_connections_same_room` | 多用户同房间 |
| `test_add_same_user_multiple_tabs` | 同用户多标签页引用计数 |
| `test_remove_connection_clears_user` | 断开后用户下线 |
| `test_remove_one_tab_keeps_user_online` | 关闭一个标签页用户仍在线 |
| `test_get_online_users` | 返回正确在线用户列表 |
| `test_broadcast_room_sends_to_all` | 广播发送给房间所有连接 |
| `test_broadcast_room_skips_failed_connections` | 广播时跳过异常连接 |
| `test_broadcast_empty_room_no_error` | 空房间广播不报错 |
| `test_remove_unknown_websocket_no_error` | 移除未知连接不报错 |

### `test_websocket.py` — 5 个集成测试
| 测试 | 说明 |
|------|------|
| `test_ws_invalid_token_closes` | 无效 token 连接被关闭 |
| `test_ws_connect_and_receive_history` | 连接后收到历史消息事件 |
| `test_ws_receives_users_event_on_connect` | 连接后收到在线用户事件 |
| `test_ws_send_and_receive_message` | 发送消息后收到广播 |
| `test_ws_empty_content_ignored` | 空内容消息被忽略 |

**总计：41 个测试**

---

## 依赖安装

测试需要额外安装以下包（在项目虚拟环境中执行）：

```bash
pip install pytest pytest-asyncio httpx
```

或将以下内容追加到 `requirements.txt` 后重新安装：

```
pytest
httpx
```

> `httpx` 是 FastAPI `TestClient` 的底层依赖，必须安装。

---

## 如何运行测试

### 运行全部测试

```bash
cd chat_app
pytest
```

### 运行单个测试文件

```bash
pytest tests/test_auth.py
pytest tests/test_rooms.py
pytest tests/test_messages.py
pytest tests/test_ws_service.py
pytest tests/test_websocket.py
```

### 运行单个测试用例

```bash
pytest tests/test_auth.py::TestLogin::test_login_success
```

### 显示详细输出

```bash
pytest -v
```

### 显示 print 输出（调试用）

```bash
pytest -s
```

### 生成覆盖率报告（需安装 pytest-cov）

```bash
pip install pytest-cov
pytest --cov=. --cov-report=term-missing
```

---

## 注意事项

- 测试使用 SQLite，**无需启动 MySQL**
- 每个测试用例执行后自动清空数据库，测试间完全隔离
- `test.db` 文件在测试结束后自动删除
- WebSocket 测试使用 FastAPI 内置的 `TestClient`，同步执行，无需 `pytest-asyncio`
- 所有测试在 `chat_app/` 目录下执行，确保 Python 路径正确
