import sys
import os

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Depends, Header
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from core.processors.text_processor import TextProcessor
from core.vector_db.faiss_vector_db import FAISSVectorDB
from core.data_flow import data_flow_manager
from core.model_manager import model_manager
from core.cache.cache_manager import cache_manager
from core.security.authentication import auth_manager
from core.backup.backup_manager import backup_manager
from config.config import config

app = FastAPI()

# 初始化处理器和向量数据库
text_processor = TextProcessor(test_mode=True)
vector_db = FAISSVectorDB()

# 删除已有的测试集合（如果存在）
vector_db.delete_collection("test_collection")
# 创建测试集合
vector_db.create_collection("test_collection", 3)

# 认证依赖
def get_current_user(api_key: Optional[str] = Header(None), authorization: Optional[str] = Header(None)):
    """获取当前用户"""
    # 验证API密钥
    if api_key and auth_manager.validate_api_key(api_key):
        return {"user_id": "api_user", "role": "api"}
    
    # 验证JWT令牌
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ")[1]
        payload = auth_manager.validate_jwt(token)
        if payload:
            return payload
    
    raise HTTPException(
        status_code=401,
        detail="Invalid authentication credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

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

class FileUploadResponse(BaseModel):
    file_id: str
    collection_id: str
    chunks_processed: int
    vectors_stored: int

class BatchFileUploadResponse(BaseModel):
    results: List[Dict[str, Any]]

class MetadataRequest(BaseModel):
    file_id: str
    metadata: Dict[str, Any]

class MetadataResponse(BaseModel):
    metadata_id: str
    status: str

class SystemStatusResponse(BaseModel):
    status: str
    config: Dict[str, Any]
    model_status: Dict[str, Any]

class ModelSwitchRequest(BaseModel):
    model_type: str
    model_name: str

class ModelSwitchResponse(BaseModel):
    status: str
    model_path: str

class BackupResponse(BaseModel):
    status: str
    backup_file: str

class BackupListResponse(BaseModel):
    backups: List[str]

class RestoreResponse(BaseModel):
    status: str
    message: str

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
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/vector/search", response_model=VectorSearchResponse)
def search_vector(request: VectorSearchRequest):
    try:
        # 生成缓存键
        cache_key = f"search:{request.collection_id}:{hash(tuple(request.query_vector))}:{request.top_k}:{hash(str(request.filters))}"
        
        # 尝试从缓存获取
        cached_results = cache_manager.get(cache_key)
        if cached_results:
            print("Cache hit!")
            return VectorSearchResponse(results=cached_results)
        
        print(f"Search request: {request}")
        results = vector_db.search(
            request.collection_id,
            request.query_vector,
            request.top_k,
            request.filters
        )
        print(f"Search successful, results: {results}")
        
        # 缓存结果
        cache_manager.set(cache_key, results)
        
        return VectorSearchResponse(results=results)
    except Exception as e:
        print(f"Search error: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/files/upload", response_model=FileUploadResponse)
async def upload_file(
    file: UploadFile = File(...),
    collection_id: str = Form(...)
):
    try:
        # 保存上传的文件
        file_path = f"temp_{file.filename}"
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
        
        # 处理文件
        result = data_flow_manager.process_file(file_path, collection_id)
        
        # 清理临时文件
        if os.path.exists(file_path):
            os.remove(file_path)
        
        return FileUploadResponse(
            file_id=result['file_id'],
            collection_id=result['collection_id'],
            chunks_processed=result['chunks_processed'],
            vectors_stored=result['vectors_stored']
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/files/batch/upload", response_model=BatchFileUploadResponse)
async def upload_batch_files(
    files: List[UploadFile] = File(...),
    collection_id: str = Form(...)
):
    try:
        file_paths = []
        
        # 保存所有上传的文件
        for file in files:
            file_path = f"temp_{file.filename}"
            with open(file_path, "wb") as f:
                content = await file.read()
                f.write(content)
            file_paths.append(file_path)
        
        # 批量处理文件
        results = data_flow_manager.process_batch_files(file_paths, collection_id)
        
        # 清理临时文件
        for file_path in file_paths:
            if os.path.exists(file_path):
                os.remove(file_path)
        
        return BatchFileUploadResponse(results=results)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/metadata/{file_id}")
def get_metadata(file_id: str):
    try:
        metadata = data_flow_manager.metadata_storage.get_metadata(file_id)
        if not metadata:
            raise HTTPException(status_code=404, detail="Metadata not found")
        return metadata
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/metadata/update", response_model=MetadataResponse)
def update_metadata(request: MetadataRequest):
    try:
        success = data_flow_manager.metadata_storage.update_metadata(
            request.file_id, request.metadata
        )
        if success:
            return MetadataResponse(
                metadata_id=request.file_id,
                status="updated"
            )
        else:
            raise HTTPException(status_code=404, detail="Metadata not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/metadata/{file_id}", response_model=MetadataResponse)
def delete_metadata(file_id: str):
    try:
        success = data_flow_manager.metadata_storage.delete_metadata(file_id)
        if success:
            return MetadataResponse(
                metadata_id=file_id,
                status="deleted"
            )
        else:
            raise HTTPException(status_code=404, detail="Metadata not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/system/status", response_model=SystemStatusResponse)
def get_system_status(current_user: Dict[str, Any] = Depends(get_current_user)):
    try:
        # 检查模型状态
        model_status = {
            'text_model': model_manager.check_model_exists(
                config.get('EMBEDDING_MODEL_NAME'), 'text'
            ),
            'image_model': model_manager.check_model_exists(
                config.get('IMAGE_PROCESSING_MODEL_NAME'), 'image'
            )
        }
        
        return SystemStatusResponse(
            status="running",
            config={k: v for k, v in config.get_all().items() if not k.endswith('_PASSWORD')},
            model_status=model_status
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/model/switch", response_model=ModelSwitchResponse)
def switch_model(request: ModelSwitchRequest, current_user: Dict[str, Any] = Depends(get_current_user)):
    try:
        # 确保模型可用
        success = model_manager.ensure_model_available(
            request.model_name, request.model_type
        )
        if success:
            model_path = model_manager.get_model_path(
                request.model_name, request.model_type
            )
            return ModelSwitchResponse(
                status="switched",
                model_path=model_path
            )
        else:
            raise HTTPException(status_code=500, detail="Failed to switch model")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/backup/create", response_model=BackupResponse)
def create_backup(current_user: Dict[str, Any] = Depends(get_current_user)):
    try:
        backup_file = backup_manager.create_backup()
        return BackupResponse(
            status="success",
            backup_file=backup_file
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/backup/list", response_model=BackupListResponse)
def list_backups(current_user: Dict[str, Any] = Depends(get_current_user)):
    try:
        backups = backup_manager.list_backups()
        return BackupListResponse(
            backups=backups
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/backup/restore/{backup_file}", response_model=RestoreResponse)
def restore_backup(backup_file: str, current_user: Dict[str, Any] = Depends(get_current_user)):
    try:
        success = backup_manager.restore_backup(backup_file)
        if success:
            return RestoreResponse(
                status="success",
                message="Backup restored successfully"
            )
        else:
            raise HTTPException(status_code=500, detail="Failed to restore backup")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/backup/delete/{backup_file}", response_model=RestoreResponse)
def delete_backup(backup_file: str, current_user: Dict[str, Any] = Depends(get_current_user)):
    try:
        success = backup_manager.delete_backup(backup_file)
        if success:
            return RestoreResponse(
                status="success",
                message="Backup deleted successfully"
            )
        else:
            raise HTTPException(status_code=500, detail="Failed to delete backup")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def root():
    return {"message": "Vector Database API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)