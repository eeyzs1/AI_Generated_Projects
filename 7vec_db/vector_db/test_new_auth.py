"""测试新的认证流程"""
from core.security.authentication import auth_manager
from client.vector_db_client import VectorDBClient

print("测试新的认证流程...")

# 测试1: 创建测试用户
print("\n1. 创建测试用户")
username = "test_user"
api_key = auth_manager.generate_api_key(username, level=5)
print(f"创建用户 {username}，API Key: {api_key}")

# 测试2: 验证用户名和API Key
print("\n2. 验证用户名和API Key")
user_info = auth_manager.validate_user(username, api_key)
print(f"用户验证结果: {user_info}")

# 测试3: 尝试使用客户端（正确的用户名和API Key）
print("\n3. 测试客户端初始化（正确的用户名和API Key）")
try:
    client = VectorDBClient(
        username=username,
        api_key=api_key
    )
    print("客户端初始化成功")
except Exception as e:
    print(f"客户端初始化失败: {e}")

# 测试4: 尝试使用客户端（缺少用户名）
print("\n4. 测试客户端初始化（缺少用户名）")
try:
    client = VectorDBClient(
        api_key=api_key
    )
    print("客户端初始化成功")
except Exception as e:
    print(f"客户端初始化失败: {e}")

# 测试5: 测试API调用（这里只是测试客户端是否能正确设置头部）
print("\n5. 测试API调用准备")
client = VectorDBClient(
    username=username,
    api_key=api_key
)
print(f"客户端创建成功，用户名: {client.username}")
print(f"请求头部: {client.headers}")

# 测试6: 删除测试用户
print("\n6. 删除测试用户")
delete_success = auth_manager.remove_user(username)
print(f"删除用户 {username} 结果: {delete_success}")

print("\n测试完成!")