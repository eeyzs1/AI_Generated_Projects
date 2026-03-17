"""测试用户认证系统"""
from core.security.authentication import auth_manager

print("测试用户认证系统...")

# 测试1: 添加新用户
print("\n1. 测试添加新用户")
username = "test_user"
api_key = auth_manager.generate_api_key(username, level=5)
print(f"创建用户 {username}，API Key: {api_key}")

# 测试2: 验证API Key
print("\n2. 测试验证API Key")
is_valid = auth_manager.validate_api_key(api_key)
print(f"API Key 验证结果: {is_valid}")

# 测试3: 验证用户和API Key
print("\n3. 测试验证用户和API Key")
user_info = auth_manager.validate_user(username, api_key)
print(f"用户验证结果: {user_info}")

# 测试4: 获取用户级别
print("\n4. 测试获取用户级别")
level = auth_manager.get_user_level(username)
print(f"用户 {username} 的级别: {level}")

# 测试5: 列出所有用户
print("\n5. 测试列出所有用户")
users = auth_manager.list_users()
print("用户列表:")
for user in users:
    print(f"  - {user['username']} (级别: {user['level']}, API Key: {user['api_key']})")

# 测试6: 删除用户
print("\n6. 测试删除用户")
delete_success = auth_manager.remove_user(username)
print(f"删除用户 {username} 结果: {delete_success}")

# 测试7: 验证删除后的API Key
print("\n7. 测试验证删除后的API Key")
is_valid_after_delete = auth_manager.validate_api_key(api_key)
print(f"删除后 API Key 验证结果: {is_valid_after_delete}")

# 测试8: 重新列出所有用户
print("\n8. 测试重新列出所有用户")
users_after_delete = auth_manager.list_users()
print("删除后的用户列表:")
for user in users_after_delete:
    print(f"  - {user['username']} (级别: {user['level']}, API Key: {user['api_key']})")

print("\n测试完成!")