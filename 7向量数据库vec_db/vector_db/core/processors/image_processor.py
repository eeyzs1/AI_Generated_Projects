from typing import List, Any
from PIL import Image
from .base_processor import BaseProcessor
from config.config import config
from sentence_transformers import SentenceTransformer

class ImageProcessor(BaseProcessor):
    def __init__(self, model_name=None):
        # 使用配置中的模型名称，如果没有提供
        if model_name is None:
            model_name = config.get('IMAGE_PROCESSING_MODEL_NAME', 'OFA-Sys/chinese-clip-vit-base-patch16')

        self.model = SentenceTransformer(model_name)
        self.use_real_model = True

    
    def chunk(self, content: Image.Image) -> List[Image.Image]:
        # 图像分块（这里简单返回原始图像）
        return [content]
    
    def clean(self, content: Image.Image) -> Image.Image:
        # 简单的图像清洗
        # 转换为RGB模式
        if content.mode != 'RGB':
            content = content.convert('RGB')
        return content
    
    def embed(self, content: Image.Image) -> List[float]:
        # 使用CLIP生成图像嵌入向量
        if self.use_real_model:
            try:
                embedding = self.model.encode(content)
                return embedding.tolist()
            except Exception as e:
                print(f"Embedding error: {e}")
                # 失败时使用模拟向量
                import random
                return [random.random() for _ in range(512)]
        else:
            # 使用模拟嵌入向量
            import random
            return [random.random() for _ in range(512)]