from typing import List, Any
from .base_processor import BaseProcessor
from config.config import config

class TextProcessor(BaseProcessor):
    def __init__(self, model_name=None):
        # 使用配置中的模型名称，如果没有提供
        if model_name is None:
            model_name = config.get('TEXT_PROCESSING_MODEL_NAME', 'shibing624/text2vec-base-chinese')
        self.model_name = model_name
        # 模拟模型，避免网络依赖
    
    def chunk(self, content: str) -> List[str]:
        # 简单的文本分块实现
        chunks = []
        words = content.split()
        chunk_size = 100  # 每个块100个词
        if not words:
            # 如果没有单词，返回一个包含空字符串的列表
            return ['']
        for i in range(0, len(words), chunk_size):
            chunk = ' '.join(words[i:i+chunk_size])
            chunks.append(chunk)
        return chunks
    
    def clean(self, content: str) -> str:
        # 简单的文本清洗
        content = content.strip()
        content = ' '.join(content.split())  # 去除多余的空白字符
        return content
    
    def embed(self, content: str) -> List[float]:
        # 模拟嵌入向量，返回固定长度的随机向量
        import random
        return [random.random() for _ in range(384)]