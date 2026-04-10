import os
from jose import JWTError, jwt
from fastapi import HTTPException, Request

ACCESS_SECRET_KEY = os.environ.get("ACCESS_SECRET_KEY", "your-access-secret-key-change-in-production")
ALGORITHM = "HS256"

def verify_access_token(token: str) -> int:
    try:
        payload = jwt.decode(token, ACCESS_SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token")
        return int(user_id)
    except JWTError:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

async def get_current_user_id(request: Request) -> int:
    auth = request.headers.get("Authorization", "")
    parts = auth.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Could not validate credentials")
    return verify_access_token(parts[1])
