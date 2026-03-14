from typing import List, Any
from PIL import Image
from .base_processor import BaseProcessor
from config.config import config
from core.model_manager import model_manager
from sentence_transformers import SentenceTransformer

class ImageProcessor(BaseProcessor):
    def __init__(self, model_type=None, model_name=None, model_path=None):
        # 使用配置中的参数，如果没有提供
        self.model_type = model_type or config.get('IMAGE_PROCESSING_MODEL_TYPE', 'local')
        self.model_name = model_name or config.get('IMAGE_PROCESSING_MODEL_NAME', 'OFA-Sys/chinese-clip-vit-base-patch16')
        self.model_path = model_path or config.get('IMAGE_PROCESSING_MODEL_PATH', './models/image')
        
        # 确保模型可用
        if self.model_type == 'local':
            model_manager.ensure_model_available(self.model_name, 'image')
        
        try:
            self.model = SentenceTransformer(self.model_name)
            self.use_real_model = True
        except Exception as e:
            print(f"加载模型失败，使用模拟模型: {e}")
            self.use_real_model = False

    
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