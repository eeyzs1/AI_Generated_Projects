from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os, uuid, shutil

from auth import get_current_user_id
from nacos_client import register_service

app = FastAPI(title="Storage Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

AVATAR_DIR = os.path.join(os.path.dirname(__file__), "static", "avatars")
UPLOAD_DIR = os.path.join(AVATAR_DIR, "uploads")
DEFAULT_DIR = os.path.join(AVATAR_DIR, "default")
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(DEFAULT_DIR, exist_ok=True)

app.mount("/api/storage/static", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")), name="static")

@app.on_event("startup")
async def startup_event():
    register_service("storage-service",
                     os.environ.get("SERVICE_HOST", "storage-service"),
                     int(os.environ.get("SERVICE_PORT", "8006")))

@app.get("/health")
def health():
    return {"status": "ok", "service": "storage-service"}

@app.post("/api/storage/upload-avatar")
async def upload_avatar(request: Request, file: UploadFile = File(...)):
    await get_current_user_id(request)
    ext = os.path.splitext(file.filename)[1] or ".png"
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = os.path.join(UPLOAD_DIR, filename)
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)
    return {"url": f"/api/storage/static/avatars/uploads/{filename}"}

@app.get("/api/storage/avatars/default")
def list_default_avatars():
    files = [f for f in os.listdir(DEFAULT_DIR) if not f.startswith(".")]
    return {"avatars": [f"/api/storage/static/avatars/default/{f}" for f in files]}
