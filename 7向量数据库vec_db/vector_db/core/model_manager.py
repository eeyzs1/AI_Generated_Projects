import os
import subprocess
from config.config import config

class ModelManager:
    def __init__(self):
        self.config = config
        self.model_paths = {
            'text': self.config.get('EMBEDDING_MODEL_PATH'),
            'image': self.config.get('IMAGE_PROCESSING_MODEL_PATH')
        }
        # 确保模型目录存在
        for path in self.model_paths.values():
            os.makedirs(path, exist_ok=True)
        # 国内源配置
        self.huggingface_mirrors = [
            "https://mirror.sjtu.edu.cn/huggingface",
            "https://hf-mirror.com",
            "https://modelscope.cn"
        ]
    
    def check_model_exists(self, model_name: str, model_type: str = 'text') -> bool:
        """检查模型是否存在"""
        model_path = self.model_paths.get(model_type)
        if not model_path:
            return False
        
        # 检查模型目录是否存在且非空
        model_dir = os.path.join(model_path, model_name.replace('/', '_'))
        return os.path.exists(model_dir) and len(os.listdir(model_dir)) > 0
    
    def download_model(self, model_name: str, model_type: str = 'text') -> bool:
        """自动下载模型，尝试国内源"""
        try:
            # 使用sentence-transformers的方式下载模型
            from sentence_transformers import SentenceTransformer
            
            model_path = self.model_paths.get(model_type)
            if not model_path:
                return False
            
            # 尝试使用国内源
            for mirror in self.huggingface_mirrors:
                try:
                    # 设置环境变量
                    os.environ['HF_ENDPOINT'] = mirror
                    print(f"尝试从国内源下载模型: {mirror}")
                    
                    # 下载模型
                    model = SentenceTransformer(model_name, cache_folder=model_path)
                    model.save(os.path.join(model_path, model_name.replace('/', '_')))
                    return True
                except Exception as e:
                    print(f"从{mirror}下载失败: {e}")
                    continue
            
            # 如果所有国内源都失败，尝试默认源
            print("尝试从默认源下载模型...")
            if 'HF_ENDPOINT' in os.environ:
                del os.environ['HF_ENDPOINT']
            model = SentenceTransformer(model_name, cache_folder=model_path)
            model.save(os.path.join(model_path, model_name.replace('/', '_')))
            return True
        except Exception as e:
            print(f"下载模型失败: {e}")
            return False
    
    def ensure_model_available(self, model_name: str, model_type: str = 'text') -> bool:
        """确保模型可用，如果不存在则自动下载"""
        if self.check_model_exists(model_name, model_type):
            return True
        else:
            print(f"模型 {model_name} 不存在，开始自动下载...")
            return self.download_model(model_name, model_type)
    
    def get_model_path(self, model_name: str, model_type: str = 'text') -> str:
        """获取模型路径"""
        model_path = self.model_paths.get(model_type)
        if not model_path:
            return ''
        return os.path.join(model_path, model_name.replace('/', '_'))

# 全局模型管理器实例
model_manager = ModelManager()