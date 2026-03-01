from functools import lru_cache
from typing import Generator

from pydantic_settings import BaseSettings
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker


class Settings(BaseSettings):
    mysql_user: str = "chat_user"
    mysql_password: str = "chat_password"
    mysql_host: str = "127.0.0.1"
    mysql_port: int = 3306
    mysql_db: str = "chat_app"
    jwt_secret_key: str = "change_this_secret"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    cors_allow_origins: str = "http://localhost:5173,http://127.0.0.1:5173"

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache
def get_settings() -> Settings:
    return Settings()


def _build_database_url(settings: Settings) -> str:
    return (
        "mysql+mysqlconnector://"
        f"{settings.mysql_user}:{settings.mysql_password}"
        f"@{settings.mysql_host}:{settings.mysql_port}/{settings.mysql_db}"
        "?charset=utf8mb4"
    )


settings = get_settings()
engine = create_engine(_build_database_url(settings), pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()


def get_db() -> Generator:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_database() -> None:
    import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
