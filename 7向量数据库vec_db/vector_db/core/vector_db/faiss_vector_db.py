import faiss
import os
import pickle
import numpy as np
from typing import List, Dict, Any
from .base_vector_db import BaseVectorDB

class FAISSVectorDB(BaseVectorDB):
    def __init__(self, db_path='./data/vector_db'):
        self.db_path = db_path
        os.makedirs(self.db_path, exist_ok=True)
        self.collections = {}
        self.metadata = {}
        self._load_collections()
    
    def _load_collections(self):
        # 加载已有的集合
        for file_name in os.listdir(self.db_path):
            if file_name.endswith('.faiss'):
                collection_id = file_name[:-6]  # 移除.faiss后缀
                index_path = os.path.join(self.db_path, file_name)
                metadata_path = os.path.join(self.db_path, f"{collection_id}.pkl")
                
                # 加载索引
                index = faiss.read_index(index_path)
                self.collections[collection_id] = index
                
                # 加载元数据
                with open(metadata_path, 'rb') as f:
                    self.metadata[collection_id] = pickle.load(f)
    
    def create_collection(self, collection_id: str, dimension: int) -> bool:
        if collection_id in self.collections:
            return False
        
        # 创建FAISS索引
        index = faiss.IndexFlatL2(dimension)
        self.collections[collection_id] = index
        self.metadata[collection_id] = {}
        
        # 保存索引和元数据
        self._save_collection(collection_id)
        return True
    
    def insert(self, collection_id: str, vectors: List[List[float]], metadata: List[Dict[str, Any]]) -> List[str]:
        if collection_id not in self.collections:
            raise ValueError(f"Collection {collection_id} does not exist")
        
        index = self.collections[collection_id]
        vector_ids = []
        
        # 插入向量
        import uuid
        try:
            for i, vector in enumerate(vectors):
                vector_id = str(uuid.uuid4())
                vector_ids.append(vector_id)
                
                # 添加向量到索引
                index.add(np.array([vector], dtype=np.float32))
                
                # 存储元数据
                self.metadata[collection_id][vector_id] = metadata[i]
            
            # 保存索引和元数据
            self._save_collection(collection_id)
            return vector_ids
        except Exception as e:
            print(f"Insert error: {str(e)}")
            raise
    
    def search(self, collection_id: str, query_vector: List[float], top_k: int, filters: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        if collection_id not in self.collections:
            raise ValueError(f"Collection {collection_id} does not exist")
        
        index = self.collections[collection_id]
        
        try:
            # 搜索向量
            distances, indices = index.search(np.array([query_vector], dtype=np.float32), top_k)
            
            # 构建结果
            results = []
            metadata_keys = list(self.metadata[collection_id].keys())
            for i, idx in enumerate(indices[0]):
                # 检查索引是否有效
                if 0 <= idx < len(metadata_keys):
                    # 查找对应的vector_id
                    vector_id = metadata_keys[idx]
                    metadata = self.metadata[collection_id][vector_id]
                    results.append({
                        'vector_id': vector_id,
                        'distance': float(distances[0][i]),
                        'metadata': metadata
                    })
            
            # 应用过滤
            if filters:
                results = [r for r in results if all(r['metadata'].get(k) == v for k, v in filters.items())]
            
            return results
        except Exception as e:
            print(f"Search error: {str(e)}")
            raise
    
    def modify(self, collection_id: str, vector_id: str, vector: List[float], metadata: Dict[str, Any]) -> bool:
        if collection_id not in self.collections:
            raise ValueError(f"Collection {collection_id} does not exist")
        
        # 查找向量索引
        idx = list(self.metadata[collection_id].keys()).index(vector_id)
        
        # 删除旧向量
        index = self.collections[collection_id]
        index.remove_ids([idx])
        
        # 插入新向量
        index.add([vector])
        
        # 更新元数据
        self.metadata[collection_id][vector_id] = metadata
        
        # 保存索引和元数据
        self._save_collection(collection_id)
        return True
    
    def delete(self, collection_id: str, vector_ids: List[str]) -> bool:
        if collection_id not in self.collections:
            raise ValueError(f"Collection {collection_id} does not exist")
        
        index = self.collections[collection_id]
        indices = []
        
        # 查找向量索引
        for vector_id in vector_ids:
            if vector_id in self.metadata[collection_id]:
                idx = list(self.metadata[collection_id].keys()).index(vector_id)
                indices.append(idx)
                del self.metadata[collection_id][vector_id]
        
        # 删除向量
        if indices:
            index.remove_ids(indices)
            # 保存索引和元数据
            self._save_collection(collection_id)
            return True
        return False
    
    def _save_collection(self, collection_id: str):
        # 保存索引
        index_path = os.path.join(self.db_path, f"{collection_id}.faiss")
        faiss.write_index(self.collections[collection_id], index_path)
        
        # 保存元数据
        metadata_path = os.path.join(self.db_path, f"{collection_id}.pkl")
        with open(metadata_path, 'wb') as f:
            pickle.dump(self.metadata[collection_id], f)
    
    def delete_collection(self, collection_id: str) -> bool:
        if collection_id not in self.collections:
            return False
        
        # 删除索引文件
        index_path = os.path.join(self.db_path, f"{collection_id}.faiss")
        if os.path.exists(index_path):
            os.remove(index_path)
        
        # 删除元数据文件
        metadata_path = os.path.join(self.db_path, f"{collection_id}.pkl")
        if os.path.exists(metadata_path):
            os.remove(metadata_path)
        
        # 从内存中删除
        del self.collections[collection_id]
        del self.metadata[collection_id]
        
        return True