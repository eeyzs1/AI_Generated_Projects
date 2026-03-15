import time
from typing import Dict, Any, Optional
from collections import OrderedDict

class CacheManager:
    def __init__(self, max_size: int = 1000, expiration_time: int = 3600):
        """初始化缓存管理器
        
        Args:
            max_size: 缓存最大容量
            expiration_time: 缓存过期时间（秒）
        """
        self.max_size = max_size
        self.expiration_time = expiration_time
        self.cache = OrderedDict()  # 使用OrderedDict实现LRU缓存
        self.cache_times = {}  # 记录缓存时间
    
    def get(self, key: str) -> Optional[Any]:
        """获取缓存
        
        Args:
            key: 缓存键
            
        Returns:
            缓存值，如果不存在或过期返回None
        """
        if key not in self.cache:
            return None
        
        # 检查是否过期
        if time.time() - self.cache_times[key] > self.expiration_time:
            self.remove(key)
            return None
        
        # 更新访问顺序（LRU）
        value = self.cache.pop(key)
        self.cache[key] = value
        self.cache_times[key] = time.time()
        
        return value
    
    def set(self, key: str, value: Any) -> None:
        """设置缓存
        
        Args:
            key: 缓存键
            value: 缓存值
        """
        # 如果缓存已满，移除最久未使用的项
        if len(self.cache) >= self.max_size:
            oldest_key = next(iter(self.cache))
            self.remove(oldest_key)
        
        # 设置缓存
        self.cache[key] = value
        self.cache_times[key] = time.time()
    
    def remove(self, key: str) -> None:
        """移除缓存
        
        Args:
            key: 缓存键
        """
        if key in self.cache:
            del self.cache[key]
            del self.cache_times[key]
    
    def clear(self) -> None:
        """清空缓存"""
        self.cache.clear()
        self.cache_times.clear()
    
    def size(self) -> int:
        """获取缓存大小"""
        return len(self.cache)
    
    def contains(self, key: str) -> bool:
        """检查缓存是否包含指定键"""
        return key in self.cache and time.time() - self.cache_times[key] <= self.expiration_time

# 全局缓存管理器实例
cache_manager = CacheManager()