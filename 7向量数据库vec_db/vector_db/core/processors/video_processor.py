import cv2
from typing import List, Any
from PIL import Image
from sentence_transformers import SentenceTransformer
from .base_processor import BaseProcessor

class VideoProcessor(BaseProcessor):
    def __init__(self, model_name='clip-vit-base-patch32'):
        self.model = SentenceTransformer(model_name)
    
    def chunk(self, content: List[cv2.Mat]) -> List[List[cv2.Mat]]:
        # 视频分块（这里简单返回原始帧列表）
        return [content]
    
    def clean(self, content: List[cv2.Mat]) -> List[cv2.Mat]:
        # 简单的视频帧清洗
        cleaned_frames = []
        for frame in content:
            # 转换为RGB格式
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            cleaned_frames.append(frame)
        return cleaned_frames
    
    def embed(self, content: List[cv2.Mat]) -> List[float]:
        # 对视频帧进行嵌入，然后取平均值
        embeddings = []
        for frame in content[:10]:  # 只取前10帧以提高速度
            # 转换为PIL Image
            pil_image = Image.fromarray(frame)
            # 生成嵌入
            embedding = self.model.encode(pil_image)
            embeddings.append(embedding)
        
        # 计算平均嵌入
        if embeddings:
            avg_embedding = sum(embeddings) / len(embeddings)
            return avg_embedding.tolist()
        return []