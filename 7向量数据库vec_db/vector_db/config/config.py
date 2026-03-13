import os
from dotenv import load_dotenv

class ConfigManager:
    def __init__(self, env_file='.env'):
        self.env_file = env_file
        self.config = self._load_config()
    
    def _load_config(self):
        load_dotenv(self.env_file)
        config = {}
        
        # 文本处理模型配置
        config['TEXT_PROCESSING_MODEL_TYPE'] = os.getenv('TEXT_PROCESSING_MODEL_TYPE', 'local')
        config['TEXT_PROCESSING_MODEL_NAME'] = os.getenv('TEXT_PROCESSING_MODEL_NAME', 'shibing624/text2vec-base-chinese')
        config['TEXT_PROCESSING_API_KEY'] = os.getenv('TEXT_PROCESSING_API_KEY', '')
        
        # 图像处理模型配置
        config['IMAGE_PROCESSING_MODEL_TYPE'] = os.getenv('IMAGE_PROCESSING_MODEL_TYPE', 'local')
        config['IMAGE_PROCESSING_MODEL_NAME'] = os.getenv('IMAGE_PROCESSING_MODEL_NAME', 'OFA-Sys/chinese-clip-vit-base-patch16')
        config['IMAGE_PROCESSING_MODEL_PATH'] = os.getenv('IMAGE_PROCESSING_MODEL_PATH', './models/image')
        
        # 文本清洗模型配置
        config['TEXT_CLEANING_MODEL_TYPE'] = os.getenv('TEXT_CLEANING_MODEL_TYPE', 'local')
        config['TEXT_CLEANING_MODEL_NAME'] = os.getenv('TEXT_CLEANING_MODEL_NAME', 'shibing624/text2vec-base-chinese')
        config['TEXT_CLEANING_API_KEY'] = os.getenv('TEXT_CLEANING_API_KEY', '')
        
        # 图像清洗模型配置
        config['IMAGE_CLEANING_MODEL_TYPE'] = os.getenv('IMAGE_CLEANING_MODEL_TYPE', 'local')
        config['IMAGE_CLEANING_MODEL_NAME'] = os.getenv('IMAGE_CLEANING_MODEL_NAME', 'OFA-Sys/chinese-clip-vit-base-patch16')
        config['IMAGE_CLEANING_MODEL_PATH'] = os.getenv('IMAGE_CLEANING_MODEL_PATH', './models/image')
        
        # 向量嵌入模型配置
        config['EMBEDDING_MODEL_TYPE'] = os.getenv('EMBEDDING_MODEL_TYPE', 'local')
        config['EMBEDDING_MODEL_NAME'] = os.getenv('EMBEDDING_MODEL_NAME', 'shibing624/text2vec-base-chinese')
        config['EMBEDDING_MODEL_PATH'] = os.getenv('EMBEDDING_MODEL_PATH', './models/embedding')
        config['EMBEDDING_API_KEY'] = os.getenv('EMBEDDING_API_KEY', '')
        
        # 向量数据库配置
        config['VECTOR_DB_TYPE'] = os.getenv('VECTOR_DB_TYPE', 'faiss')
        config['VECTOR_DB_PATH'] = os.getenv('VECTOR_DB_PATH', './data/vector_db')
        
        # 元数据存储配置
        config['METADATA_STORAGE_TYPE'] = os.getenv('METADATA_STORAGE_TYPE', 'mysql')
        config['MYSQL_HOST'] = os.getenv('MYSQL_HOST', 'localhost')
        config['MYSQL_PORT'] = int(os.getenv('MYSQL_PORT', '3306'))
        config['MYSQL_USER'] = os.getenv('MYSQL_USER', 'root')
        config['MYSQL_PASSWORD'] = os.getenv('MYSQL_PASSWORD', 'password')
        config['MYSQL_DATABASE'] = os.getenv('MYSQL_DATABASE', 'vector_db')
        
        # Redis配置
        config['REDIS_HOST'] = os.getenv('REDIS_HOST', 'localhost')
        config['REDIS_PORT'] = int(os.getenv('REDIS_PORT', '6379'))
        config['REDIS_PASSWORD'] = os.getenv('REDIS_PASSWORD', '')
        config['REDIS_DB'] = int(os.getenv('REDIS_DB', '0'))
        
        # MongoDB配置
        config['MONGO_HOST'] = os.getenv('MONGO_HOST', 'localhost')
        config['MONGO_PORT'] = int(os.getenv('MONGO_PORT', '27017'))
        config['MONGO_USER'] = os.getenv('MONGO_USER', '')
        config['MONGO_PASSWORD'] = os.getenv('MONGO_PASSWORD', '')
        config['MONGO_DATABASE'] = os.getenv('MONGO_DATABASE', 'vector_db')
        
        # 文件存储配置
        config['FILE_STORAGE_TYPE'] = os.getenv('FILE_STORAGE_TYPE', 'local')
        config['LOCAL_STORAGE_PATH'] = os.getenv('LOCAL_STORAGE_PATH', './data/files')
        
        # S3配置
        config['S3_BUCKET_NAME'] = os.getenv('S3_BUCKET_NAME', '')
        config['S3_ACCESS_KEY'] = os.getenv('S3_ACCESS_KEY', '')
        config['S3_SECRET_KEY'] = os.getenv('S3_SECRET_KEY', '')
        config['S3_REGION'] = os.getenv('S3_REGION', 'us-east-1')
        
        # API配置
        config['API_PORT'] = int(os.getenv('API_PORT', '8000'))
        config['API_HOST'] = os.getenv('API_HOST', '0.0.0.0')
        config['API_SECRET_KEY'] = os.getenv('API_SECRET_KEY', 'your-api-secret-key')
        
        # 日志配置
        config['LOG_LEVEL'] = os.getenv('LOG_LEVEL', 'INFO')
        config['LOG_FILE'] = os.getenv('LOG_FILE', './logs/app.log')
        
        return config
    
    def get(self, key, default=None):
        return self.config.get(key, default)
    
    def get_all(self):
        return self.config

# 全局配置实例
config = ConfigManager()