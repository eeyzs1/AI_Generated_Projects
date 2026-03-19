from fastapi import HTTPException, Request
from jose import jwt, JWTError
import os

ACCESS_SECRET_KEY = os.environ.get("ACCESS_SECRET_KEY", "changeme")
ALGORITHM = "HS256"

async def get_current_user_id(request: Request) -> int:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, "Missing token")
    token = auth[7:]
    try:
        payload = jwt.decode(token, ACCESS_SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(401, "Invalid token")
        return int(user_id)
    except JWTError:
        raise HTTPException(401, "Invalid token")
