import time
from typing import List, Any
from .base_processor import BaseProcessor
from config.config import config
from core.model_manager import model_manager

class TextProcessor(BaseProcessor):
    def __init__(self, model_type=None, model_name=None, api_key=None, model_path=None, test_mode=False):
        # 使用配置中的参数，如果没有提供
        self.model_type = model_type or config.get('TEXT_PROCESSING_MODEL_TYPE', 'local')
        self.model_name = model_name or config.get('TEXT_PROCESSING_MODEL_NAME', 'shibing624/text2vec-base-chinese')
        self.api_key = api_key or config.get('TEXT_PROCESSING_API_KEY', '')
        self.model_path = model_path or config.get('EMBEDDING_MODEL_PATH', './models/embedding')
        self.test_mode = test_mode
        
        # 确保模型可用，但即使失败也继续运行
        if self.model_type == 'local' and not self.test_mode:
            try:
                model_manager.ensure_model_available(self.model_name, 'text')
            except Exception as e:
                print(f"模型下载失败: {e}")
    
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
        start_time = time.time()
        # 模拟嵌入向量，返回固定长度的随机向量
        import random
        embedding = [random.random() for _ in range(384)]
        
        # 记录模型使用情况
        processing_time = time.time() - start_time
        model_manager.record_model_usage(self.model_name, 'text', processing_time)
        
        return embedding