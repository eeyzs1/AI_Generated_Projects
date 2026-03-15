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
        try:
            self._save_collection(collection_id)
            return True
        except Exception as e:
            print(f"Create collection error: {str(e)}")
            return False
    
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
                
                # 存储元数据，包含向量
                meta_with_vector = metadata[i].copy()
                meta_with_vector['vector'] = vector
                self.metadata[collection_id][vector_id] = meta_with_vector
            
            # 保存索引和元数据
            self._save_collection(collection_id)
            return vector_ids
        except Exception as e:
            print(f"Insert error: {str(e)}")
            raise
    
    def batch_insert(self, collection_id: str, vectors: List[List[float]], metadata: List[Dict[str, Any]], batch_size: int = 1000) -> List[str]:
        """批量插入向量"""
        if collection_id not in self.collections:
            raise ValueError(f"Collection {collection_id} does not exist")
        
        index = self.collections[collection_id]
        vector_ids = []
        import uuid
        
        try:
            # 分批处理
            for i in range(0, len(vectors), batch_size):
                batch_vectors = vectors[i:i+batch_size]
                batch_metadata = metadata[i:i+batch_size]
                batch_ids = []
                
                # 生成向量ID
                for _ in range(len(batch_vectors)):
                    vector_id = str(uuid.uuid4())
                    batch_ids.append(vector_id)
                
                # 批量添加向量
                vectors_np = np.array(batch_vectors, dtype=np.float32)
                index.add(vectors_np)
                
                # 存储元数据，包含向量
                for vector_id, meta, vector in zip(batch_ids, batch_metadata, batch_vectors):
                    meta_with_vector = meta.copy()
                    meta_with_vector['vector'] = vector
                    self.metadata[collection_id][vector_id] = meta_with_vector
                
                # 添加到结果列表
                vector_ids.extend(batch_ids)
            
            # 保存索引和元数据
            self._save_collection(collection_id)
            return vector_ids
        except Exception as e:
            print(f"Batch insert error: {str(e)}")
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
            import numpy as np
            index.remove_ids(np.array(indices, dtype=np.int64))
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
    
    def optimize_index(self, collection_id: str, nlist: int = 100) -> bool:
        """优化索引，使用IVF索引提高搜索速度"""
        if collection_id not in self.collections:
            raise ValueError(f"Collection {collection_id} does not exist")
        
        try:
            # 获取当前索引
            index = self.collections[collection_id]
            dimension = index.d
            
            # 确保nlist不大于训练数据的数量
            nlist = min(nlist, index.ntotal)
            if nlist < 1:
                nlist = 1
            
            # 创建IVF索引
            quantizer = faiss.IndexFlatL2(dimension)
            ivf_index = faiss.IndexIVFFlat(quantizer, dimension, nlist, faiss.METRIC_L2)
            
            # 训练索引
            # 获取所有向量
            vectors = []
            metadata_keys = list(self.metadata[collection_id].keys())
            for i in range(index.ntotal):
                vector = index.reconstruct(i)
                vectors.append(vector.tolist())
            
            if vectors:
                vectors_np = np.array(vectors, dtype=np.float32)
                ivf_index.train(vectors_np)
                
                # 插入向量
                ivf_index.add(vectors_np)
                
                # 替换索引
                self.collections[collection_id] = ivf_index
                
                # 保存索引
                self._save_collection(collection_id)
                return True
            return False
        except Exception as e:
            print(f"Optimize index error: {str(e)}")
            raise
    
    def rebuild_index(self, collection_id: str) -> bool:
        """重建索引"""
        if collection_id not in self.collections:
            raise ValueError(f"Collection {collection_id} does not exist")
        
        try:
            # 获取当前索引
            index = self.collections[collection_id]
            dimension = index.d
            
            # 创建新的Flat索引
            new_index = faiss.IndexFlatL2(dimension)
            
            # 重建向量
            vectors = []
            metadata_keys = list(self.metadata[collection_id].keys())
            
            # 检查是否是IVF索引
            if hasattr(index, 'ntotal') and index.ntotal > 0:
                # 对于IVF索引，我们需要使用不同的方式获取向量
                # 这里简化处理，直接从元数据中获取向量（如果有的话）
                # 注意：这只是一个临时解决方案，实际应用中可能需要更复杂的处理
                if metadata_keys and 'vector' in self.metadata[collection_id][metadata_keys[0]]:
                    # 从元数据中获取向量
                    for vector_id in metadata_keys:
                        if 'vector' in self.metadata[collection_id][vector_id]:
                            vectors.append(self.metadata[collection_id][vector_id]['vector'])
                else:
                    # 如果元数据中没有向量，尝试使用reconstruct方法
                    try:
                        for i in range(index.ntotal):
                            vector = index.reconstruct(i)
                            vectors.append(vector)
                    except RuntimeError:
                        # 如果reconstruct失败，返回False
                        return False
            
            if vectors:
                vectors_np = np.array(vectors, dtype=np.float32)
                new_index.add(vectors_np)
                
                # 替换索引
                self.collections[collection_id] = new_index
                
                # 保存索引
                self._save_collection(collection_id)
                return True
            return False
        except Exception as e:
            print(f"Rebuild index error: {str(e)}")
            return False
    
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