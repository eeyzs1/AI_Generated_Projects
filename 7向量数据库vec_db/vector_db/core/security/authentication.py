import time
import jwt
from typing import Optional, Dict, Any
from config.config import config

class AuthenticationManager:
    def __init__(self):
        """初始化认证管理器"""
        self.secret_key = config.get('API_SECRET_KEY', 'your-api-secret-key')
        self.api_keys = set()
        # 从配置中加载API密钥
        api_key = config.get('API_KEY')
        if api_key:
            self.api_keys.add(api_key)
    
    def validate_api_key(self, api_key: str) -> bool:
        """验证API密钥
        
        Args:
            api_key: API密钥
            
        Returns:
            是否有效
        """
        return api_key in self.api_keys
    
    def generate_jwt(self, user_id: str, role: str = 'user') -> str:
        """生成JWT令牌
        
        Args:
            user_id: 用户ID
            role: 用户角色
            
        Returns:
            JWT令牌
        """
        payload = {
            'user_id': user_id,
            'role': role,
            'exp': time.time() + 3600  # 1小时过期
        }
        return jwt.encode(payload, self.secret_key, algorithm='HS256')
    
    def validate_jwt(self, token: str) -> Optional[Dict[str, Any]]:
        """验证JWT令牌
        
        Args:
            token: JWT令牌
            
        Returns:
            令牌 payload，如果无效返回None
        """
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=['HS256'])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
    
    def add_api_key(self, api_key: str) -> None:
        """添加API密钥
        
        Args:
            api_key: API密钥
        """
        self.api_keys.add(api_key)
    
    def remove_api_key(self, api_key: str) -> None:
        """移除API密钥
        
        Args:
            api_key: API密钥
        """
        if api_key in self.api_keys:
            self.api_keys.remove(api_key)

# 全局认证管理器实例
auth_manager = AuthenticationManager()