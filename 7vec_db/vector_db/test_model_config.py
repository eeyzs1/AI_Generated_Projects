"""测试模型配置的使用情况"""
from config.config import config
from core.processors.text_processor import TextProcessor
from core.processors.image_processor import ImageProcessor
from core.model_manager import model_manager

print("测试模型配置...")

# 测试1: 查看配置文件中的模型配置
print("\n1. 查看配置文件中的模型配置")
print("文本处理模型配置:")
print(f"  类型: {config.get('TEXT_PROCESSING_MODEL_TYPE')}")
print(f"  名称: {config.get('TEXT_PROCESSING_MODEL_NAME')}")
print(f"  路径: {config.get('TEXT_PROCESSING_MODEL_PATH')}")
print(f"  API Key: {config.get('TEXT_PROCESSING_API_KEY')}")
print(f"  Base URL: {config.get('TEXT_PROCESSING_BASE_URL')}")

print("\n图像处理模型配置:")
print(f"  类型: {config.get('IMAGE_PROCESSING_MODEL_TYPE')}")
print(f"  名称: {config.get('IMAGE_PROCESSING_MODEL_NAME')}")
print(f"  路径: {config.get('IMAGE_PROCESSING_MODEL_PATH')}")
print(f"  API Key: {config.get('IMAGE_PROCESSING_API_KEY')}")
print(f"  Base URL: {config.get('IMAGE_PROCESSING_BASE_URL')}")

print("\n嵌入模型配置:")
print(f"  类型: {config.get('EMBEDDING_MODEL_TYPE')}")
print(f"  名称: {config.get('EMBEDDING_MODEL_NAME')}")
print(f"  路径: {config.get('EMBEDDING_MODEL_PATH')}")
print(f"  API Key: {config.get('EMBEDDING_API_KEY')}")
print(f"  Base URL: {config.get('EMBEDDING_BASE_URL')}")

# 测试2: 测试apply_model_config方法
print("\n2. 测试apply_model_config方法")
text_config = config.apply_model_config('text')
print(f"文本模型配置: {text_config}")

image_config = config.apply_model_config('image')
print(f"图像模型配置: {image_config}")

embedding_config = config.apply_model_config('embedding')
print(f"嵌入模型配置: {embedding_config}")

# 测试3: 测试文本处理器
print("\n3. 测试文本处理器")
text_processor = TextProcessor(test_mode=True)
print(f"文本处理器配置:")
print(f"  类型: {text_processor.model_type}")
print(f"  名称: {text_processor.model_name}")
print(f"  路径: {text_processor.model_path}")
print(f"  API Key: {text_processor.api_key}")
print(f"  Base URL: {text_processor.base_url}")

# 测试4: 测试图像处理器
print("\n4. 测试图像处理器")
image_processor = ImageProcessor(test_mode=True)
print(f"图像处理器配置:")
print(f"  类型: {image_processor.model_type}")
print(f"  名称: {image_processor.model_name}")
print(f"  路径: {image_processor.model_path}")
print(f"  API Key: {image_processor.api_key}")
print(f"  Base URL: {image_processor.base_url}")

# 测试5: 测试模型管理器
print("\n5. 测试模型管理器")
print(f"模型路径配置: {model_manager.model_paths}")

print("\n测试完成!")