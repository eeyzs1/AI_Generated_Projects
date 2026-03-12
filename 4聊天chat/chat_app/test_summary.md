# 测试总结

## 测试文件结构

```
chat_app/
├── tests/
│   ├── conftest.py        # 测试配置文件
│   ├── test_auth.py       # 用户认证测试
│   ├── test_room.py       # 聊天室测试
│   └── test_message.py    # 消息测试
└── test_summary.md        # 测试总结文档
```

## 测试文件说明

### 1. conftest.py
- **作用**：配置测试环境
- **内容**：
  - 设置内存数据库（SQLite）用于测试
  - 创建测试数据库表
  - 覆盖数据库依赖项
  - 创建测试客户端
  - 提供测试夹具（fixtures）

### 2. test_auth.py
- **作用**：测试用户认证相关功能
- **测试用例**：
  - `test_register`：测试用户注册
  - `test_login`：测试用户登录
  - `test_get_current_user`：测试获取当前用户信息

### 3. test_room.py
- **作用**：测试聊天室相关功能
- **测试用例**：
  - `test_create_room`：测试创建聊天室
  - `test_get_rooms`：测试获取用户的聊天室列表
  - `test_add_user_to_room`：测试添加用户到聊天室

### 4. test_message.py
- **作用**：测试消息相关功能
- **测试用例**：
  - `test_send_message`：测试发送消息
  - `test_get_room_messages`：测试获取聊天室消息

## 如何执行测试

### 1. 安装测试依赖

```bash
pip install pytest pytest-cov
```

### 2. 运行测试

#### 运行所有测试

```bash
pytest
```

#### 运行特定测试文件

```bash
pytest tests/test_auth.py
pytest tests/test_room.py
pytest tests/test_message.py
```

#### 运行特定测试用例

```bash
pytest tests/test_auth.py::test_register
```

#### 生成测试覆盖率报告

```bash
pytest --cov=.
```

#### 生成HTML格式的测试覆盖率报告

```bash
pytest --cov=. --cov-report=html
```

## 测试环境说明

- **数据库**：使用SQLite内存数据库，避免影响生产数据
- **测试顺序**：测试用例之间相互独立，可并行运行
- **测试数据**：每次测试会创建新的测试数据，测试完成后自动清理

## 预期测试结果

所有测试用例应该通过，测试覆盖率应该达到80%以上。

## 注意事项

- 确保已安装所有依赖项
- 确保数据库连接配置正确
- 测试过程中会创建临时数据库文件`test.db`，测试完成后可删除
- 生产环境中应使用独立的测试数据库，避免影响生产数据