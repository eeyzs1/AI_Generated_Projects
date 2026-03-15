import unittest
import os
import sys
import pytest
from fastapi.testclient import TestClient
# 添加项目根目录到Python路径
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))

# 模拟配置，避免模型下载
os.environ['TEXT_PROCESSING_MODEL_TYPE'] = 'local'
os.environ['TEXT_PROCESSING_MODEL_NAME'] = 'test-model'
os.environ['VECTOR_DB_TYPE'] = 'faiss'
os.environ['VECTOR_DB_PATH'] = './data/vector_db'
os.environ['METADATA_STORAGE_TYPE'] = 'memory'
os.environ['FILE_STORAGE_TYPE'] = 'local'
os.environ['LOCAL_STORAGE_PATH'] = './data/files'

from api.main import app

class TestAPI(unittest.TestCase):
    def setUp(self):
        # 创建测试客户端
        self.client = TestClient(app)
        # 测试集合ID
        self.collection_id = "test_collection"
    
    @pytest.mark.timeout(5)
    def test_root_endpoint(self):
        """测试根端点，预计执行时间：1秒"""
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"message": "Vector Database API"})
    
    @pytest.mark.timeout(5)
    def test_process_text_endpoint(self):
        """测试文本处理端点，预计执行时间：5秒"""
        test_text = "This is a test text for API testing"
        response = self.client.post("/api/process/text", json={"text": test_text})
        self.assertEqual(response.status_code, 200)
        response_data = response.json()
        self.assertIn("embedding", response_data)
        self.assertIn("chunks", response_data)
        self.assertIsInstance(response_data["embedding"], list)
        self.assertIsInstance(response_data["chunks"], list)
    
    @pytest.mark.timeout(5)
    def test_insert_vector_endpoint(self):
        """测试向量插入端点，预计执行时间：5秒"""
        test_vectors = [[0.1] * 384, [0.2] * 384]
        test_metadata = [{"file_id": "1", "file_type": "text"}, {"file_id": "2", "file_type": "text"}]
        response = self.client.post("/api/vector/insert", json={
            "collection_id": self.collection_id,
            "vectors": test_vectors,
            "metadata": test_metadata
        })
        self.assertEqual(response.status_code, 200)
        response_data = response.json()
        self.assertIn("vector_ids", response_data)
        self.assertIsInstance(response_data["vector_ids"], list)
        self.assertEqual(len(response_data["vector_ids"]), 2)
    
    @pytest.mark.timeout(5)
    def test_search_vector_endpoint(self):
        """测试向量搜索端点，预计执行时间：5秒"""
        # 先插入测试向量
        test_vectors = [[0.1] * 384, [0.2] * 384]
        test_metadata = [{"file_id": "1", "file_type": "text"}, {"file_id": "2", "file_type": "text"}]
        self.client.post("/api/vector/insert", json={
            "collection_id": self.collection_id,
            "vectors": test_vectors,
            "metadata": test_metadata
        })
        
        # 测试搜索
        test_query_vector = [0.1] * 384
        response = self.client.post("/api/vector/search", json={
            "collection_id": self.collection_id,
            "query_vector": test_query_vector,
            "top_k": 2
        })
        self.assertEqual(response.status_code, 200)
        response_data = response.json()
        self.assertIn("results", response_data)
        self.assertIsInstance(response_data["results"], list)
        self.assertGreater(len(response_data["results"]), 0)

if __name__ == '__main__':
    unittest.main()