from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
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

CDN_BASE_URL = os.environ.get("CDN_BASE_URL", "")

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

    if CDN_BASE_URL:
        url = f"{CDN_BASE_URL}/static/avatars/uploads/{filename}"
    else:
        url = f"/api/storage/static/avatars/uploads/{filename}"

    return {"url": url}

@app.get("/api/storage/avatars/default")
def list_default_avatars():
    files = [f for f in os.listdir(DEFAULT_DIR) if not f.startswith(".")]
    base = f"{CDN_BASE_URL}/static/avatars/default" if CDN_BASE_URL else "/api/storage/static/avatars/default"
    return {"avatars": [f"{base}/{f}" for f in files]}

@app.get("/api/storage/static/avatars/default/{filename}")
async def serve_default_avatar(filename: str):
    filepath = os.path.join(DEFAULT_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(404, "File not found")
    return FileResponse(
        path=filepath,
        headers={"Cache-Control": "public, max-age=86400"}
    )

@app.get("/api/storage/static/avatars/uploads/{filename}")
async def serve_uploaded_avatar(filename: str):
    filepath = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(404, "File not found")
    return FileResponse(
        path=filepath,
        headers={"Cache-Control": "public, max-age=3600"}
    )
