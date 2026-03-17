"""测试 URL 配置是否正确"""
from config.config import config
from client.vector_db_client import VectorDBClient

print("测试 URL 配置...")

# 测试配置文件中的 BASE_URL
base_url = config.get('BASE_URL')
print(f"配置文件中的 BASE_URL: {base_url}")

# 测试客户端默认 URL
client = VectorDBClient()
print(f"客户端默认 URL: {client.base_url}")

# 测试 API 配置
api_host = config.get('API_HOST')
api_port = config.get('API_PORT')
print(f"API 配置 - 主机: {api_host}, 端口: {api_port}")

print("测试完成!")