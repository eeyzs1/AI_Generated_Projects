import sys
import os

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any
from core.processors.text_processor import TextProcessor
from core.vector_db.faiss_vector_db import FAISSVectorDB

app = FastAPI()

# 初始化处理器和向量数据库
text_processor = TextProcessor()
vector_db = FAISSVectorDB()

# 创建测试集合
vector_db.create_collection("test_collection", 384)

# 请求和响应模型
class TextProcessRequest(BaseModel):
    text: str

class VectorInsertRequest(BaseModel):
    collection_id: str
    vectors: List[List[float]]
    metadata: List[Dict[str, Any]]

class VectorSearchRequest(BaseModel):
    collection_id: str
    query_vector: List[float]
    top_k: int
    filters: Dict[str, Any] = None

class TextProcessResponse(BaseModel):
    embedding: List[float]
    chunks: List[str]

class VectorInsertResponse(BaseModel):
    vector_ids: List[str]

class VectorSearchResponse(BaseModel):
    results: List[Dict[str, Any]]

@app.post("/api/process/text", response_model=TextProcessResponse)
def process_text(request: TextProcessRequest):
    try:
        # 分块
        chunks = text_processor.chunk(request.text)
        # 嵌入
        embedding = text_processor.embed(request.text)
        return TextProcessResponse(embedding=embedding, chunks=chunks)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/vector/insert", response_model=VectorInsertResponse)
def insert_vector(request: VectorInsertRequest):
    try:
        print(f"Insert request: {request}")
        vector_ids = vector_db.insert(
            request.collection_id,
            request.vectors,
            request.metadata
        )
        print(f"Insert successful, vector_ids: {vector_ids}")
        return VectorInsertResponse(vector_ids=vector_ids)
    except Exception as e:
        print(f"Insert error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/vector/search", response_model=VectorSearchResponse)
def search_vector(request: VectorSearchRequest):
    try:
        print(f"Search request: {request}")
        results = vector_db.search(
            request.collection_id,
            request.query_vector,
            request.top_k,
            request.filters
        )
        print(f"Search successful, results: {results}")
        return VectorSearchResponse(results=results)
    except Exception as e:
        print(f"Search error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def root():
    return {"message": "Vector Database API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)