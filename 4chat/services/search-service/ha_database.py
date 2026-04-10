import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

DATABASE_URL = os.environ.get("DATABASE_URL", "")
DATABASE_SLAVE_URL = os.environ.get("DATABASE_SLAVE_URL", DATABASE_URL)

write_engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=10, max_overflow=20)
read_engine = create_engine(DATABASE_SLAVE_URL, pool_pre_ping=True, pool_size=10, max_overflow=20)

WriteSession = sessionmaker(autocommit=False, autoflush=False, bind=write_engine)
ReadSession = sessionmaker(autocommit=False, autoflush=False, bind=read_engine)

def get_write_db():
    db = WriteSession()
    try:
        yield db
    finally:
        db.close()

def get_read_db():
    db = ReadSession()
    try:
        yield db
    finally:
        db.close()

def get_db():
    yield from get_write_db()


def get_redis_client():
    cluster_hosts_env = os.environ.get("REDIS_CLUSTER_HOSTS", "")
    sentinel_hosts_env = os.environ.get("REDIS_SENTINEL_HOSTS", "")
    sentinel_master = os.environ.get("REDIS_SENTINEL_MASTER", "mymaster")
    redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

    if cluster_hosts_env:
        from redis.cluster import RedisCluster, ClusterNode
        nodes = [
            ClusterNode(h.split(":")[0], int(h.split(":")[1]))
            for h in cluster_hosts_env.split(",")
        ]
        return RedisCluster(startup_nodes=nodes, decode_responses=True)
    elif sentinel_hosts_env:
        import redis
        sentinel_hosts = [
            (h.split(":")[0], int(h.split(":")[1]))
            for h in sentinel_hosts_env.split(",")
        ]
        sentinel = redis.Sentinel(sentinel_hosts, socket_timeout=0.5, decode_responses=True)
        return sentinel.master_for(sentinel_master, socket_timeout=0.5)
    else:
        import redis
        return redis.from_url(redis_url, decode_responses=True)


async def get_async_redis_client():
    cluster_hosts_env = os.environ.get("REDIS_CLUSTER_HOSTS", "")
    sentinel_hosts_env = os.environ.get("REDIS_SENTINEL_HOSTS", "")
    sentinel_master = os.environ.get("REDIS_SENTINEL_MASTER", "mymaster")
    redis_url = os.environ.get("REDIS_URL", "redis://redis:6379/0")

    if cluster_hosts_env:
        from redis.asyncio.cluster import RedisCluster, ClusterNode
        nodes = [
            ClusterNode(h.split(":")[0], int(h.split(":")[1]))
            for h in cluster_hosts_env.split(",")
        ]
        return RedisCluster(startup_nodes=nodes, decode_responses=True)
    elif sentinel_hosts_env:
        from redis.asyncio.sentinel import Sentinel
        sentinel_hosts = [
            (h.split(":")[0], int(h.split(":")[1]))
            for h in sentinel_hosts_env.split(",")
        ]
        sentinel = Sentinel(sentinel_hosts, socket_timeout=0.5)
        return sentinel.master_for(sentinel_master, decode_responses=True)
    else:
        import redis.asyncio as aioredis
        return aioredis.from_url(redis_url, decode_responses=True)
