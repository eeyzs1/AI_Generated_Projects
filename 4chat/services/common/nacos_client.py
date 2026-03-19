"""
Nacos 服务发现客户端
提供服务注册和地址查询功能，替代硬编码的环境变量
"""
import os
import random
import logging
from typing import Optional

logger = logging.getLogger(__name__)

NACOS_HOST = os.environ.get("NACOS_HOST", "localhost")
NACOS_PORT = int(os.environ.get("NACOS_PORT", "8848"))
NACOS_SERVER = f"{NACOS_HOST}:{NACOS_PORT}"


def get_nacos_client():
    try:
        import nacos
        return nacos.NacosClient(NACOS_SERVER, namespace="")
    except Exception as e:
        logger.warning(f"Failed to create Nacos client: {e}")
        return None


def register_service(service_name: str, host: str, port: int):
    """注册服务到 Nacos"""
    client = get_nacos_client()
    if not client:
        return
    try:
        client.add_naming_instance(service_name, host, port)
        logger.info(f"Registered {service_name} ({host}:{port}) to Nacos")
    except Exception as e:
        logger.warning(f"Nacos registration failed (non-fatal): {e}")


def deregister_service(service_name: str, host: str, port: int):
    """从 Nacos 注销服务"""
    client = get_nacos_client()
    if not client:
        return
    try:
        client.remove_naming_instance(service_name, host, port)
        logger.info(f"Deregistered {service_name} from Nacos")
    except Exception as e:
        logger.warning(f"Nacos deregistration failed (non-fatal): {e}")


def get_service_url(service_name: str, fallback_env: str) -> str:
    """
    从 Nacos 查询服务地址，支持客户端负载均衡（随机选择）
    若 Nacos 不可用则回退到环境变量
    """
    client = get_nacos_client()
    if client:
        try:
            instances = client.list_naming_instance(service_name, healthy_only=True)
            hosts = instances.get("hosts", [])
            if hosts:
                # 随机负载均衡
                instance = random.choice(hosts)
                url = f"http://{instance['ip']}:{instance['port']}"
                logger.debug(f"Resolved {service_name} → {url} via Nacos")
                return url
        except Exception as e:
            logger.warning(f"Nacos lookup failed for {service_name}, using fallback: {e}")

    # 回退到环境变量
    fallback = os.environ.get(fallback_env, "")
    logger.debug(f"Resolved {service_name} → {fallback} via env fallback")
    return fallback
