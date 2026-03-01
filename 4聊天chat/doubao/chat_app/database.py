from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

# MySQL数据库配置（请根据实际环境修改）
SQLALCHEMY_DATABASE_URL = "mysql+asyncmy://root:password@localhost:3306/chat_app"

# 异步引擎配置
async_engine = create_async_engine(
    SQLALCHEMY_DATABASE_URL,
    echo=True,
    pool_pre_ping=True,
)
AsyncSessionLocal = sessionmaker(
    async_engine, class_=AsyncSession, expire_on_commit=False
)

# 同步引擎（可选，用于初始化数据库）
sync_engine = create_engine(
    SQLALCHEMY_DATABASE_URL.replace("+asyncmy", ""),
    echo=True,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=sync_engine)

# ORM基类
Base = declarative_base()

# 获取异步数据库会话
async def get_db():
    db = AsyncSessionLocal()
    try:
        yield db
    finally:
        await db.close()

# 初始化数据库表
async def init_db():
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
