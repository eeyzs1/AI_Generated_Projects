"""
高可用数据库连接工具
支持 MySQL 读写分离、Redis 哨兵模式、Redis 集群模式

Redis 模式选择（通过环境变量控制，三选一）：
  - 普通模式：只设置 REDIS_URL
  - 哨兵模式：设置 REDIS_SENTINEL_HOSTS + REDIS_SENTINEL_MASTER
  - 集群模式：设置 REDIS_CLUSTER_HOSTS
"""
import os

# connector-service 不使用 MySQL，仅使用 Redis 和 Kafka

# ── Redis 哨兵/集群/普通 三模式 ──────────────────────────────
def get_redis_client():
    """
    同步 Redis 客户端
    优先级：集群模式 > 哨兵模式 > 普通模式
    """
    cluster_hosts_env = os.environ.get("REDIS_CLUSTER_HOSTS", "")
    sentinel_hosts_env = os.environ.get("REDIS_SENTINEL_HOSTS", "")
    sentinel_master = os.environ.get("REDIS_SENTINEL_MASTER", "mymaster")
    redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

    if cluster_hosts_env:
        # 集群模式：REDIS_CLUSTER_HOSTS=node1:6379,node2:6379,node3:6379
        from redis.cluster import RedisCluster, ClusterNode
        nodes = [
            ClusterNode(h.split(":")[0], int(h.split(":")[1]))
            for h in cluster_hosts_env.split(",")
        ]
        return RedisCluster(startup_nodes=nodes, decode_responses=True)
    elif sentinel_hosts_env:
        # 哨兵模式：REDIS_SENTINEL_HOSTS=sentinel1:26379,sentinel2:26379,sentinel3:26379
        import redis
        sentinel_hosts = [
            (h.split(":")[0], int(h.split(":")[1]))
            for h in sentinel_hosts_env.split(",")
        ]
        sentinel = redis.Sentinel(sentinel_hosts, socket_timeout=0.5, decode_responses=True)
        return sentinel.master_for(sentinel_master, socket_timeout=0.5)
    else:
        # 普通模式
        import redis
        return redis.from_url(redis_url, decode_responses=True)


async def get_async_redis_client():
    """
    异步 Redis 客户端
    优先级：集群模式 > 哨兵模式 > 普通模式
    """
    cluster_hosts_env = os.environ.get("REDIS_CLUSTER_HOSTS", "")
    sentinel_hosts_env = os.environ.get("REDIS_SENTINEL_HOSTS", "")
    sentinel_master = os.environ.get("REDIS_SENTINEL_MASTER", "mymaster")
    redis_url = os.environ.get("REDIS_URL", "redis://redis:6379/0")

    if cluster_hosts_env:
        # 集群模式
        from redis.asyncio.cluster import RedisCluster, ClusterNode
        nodes = [
            ClusterNode(h.split(":")[0], int(h.split(":")[1]))
            for h in cluster_hosts_env.split(",")
        ]
        return RedisCluster(startup_nodes=nodes, decode_responses=True)
    elif sentinel_hosts_env:
        # 哨兵模式
        from redis.asyncio.sentinel import Sentinel
        sentinel_hosts = [
            (h.split(":")[0], int(h.split(":")[1]))
            for h in sentinel_hosts_env.split(",")
        ]
        sentinel = Sentinel(sentinel_hosts, socket_timeout=0.5)
        return sentinel.master_for(sentinel_master, decode_responses=True)
    else:
        # 普通模式
        import redis.asyncio as aioredis
        return aioredis.from_url(redis_url, decode_responses=True)
