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
    client = get_nacos_client()
    if not client:
        return
    try:
        client.add_naming_instance(service_name, host, port)
        logger.info(f"Registered {service_name} ({host}:{port}) to Nacos")
    except Exception as e:
        logger.warning(f"Nacos registration failed (non-fatal): {e}")


def deregister_service(service_name: str, host: str, port: int):
    client = get_nacos_client()
    if not client:
        return
    try:
        client.remove_naming_instance(service_name, host, port)
        logger.info(f"Deregistered {service_name} from Nacos")
    except Exception as e:
        logger.warning(f"Nacos deregistration failed (non-fatal): {e}")


def get_service_url(service_name: str, fallback_env: str) -> str:
    client = get_nacos_client()
    if client:
        try:
            instances = client.list_naming_instance(service_name, healthy_only=True)
            hosts = instances.get("hosts", [])
            if hosts:
                instance = random.choice(hosts)
                url = f"http://{instance['ip']}:{instance['port']}"
                logger.debug(f"Resolved {service_name} -> {url} via Nacos")
                return url
        except Exception as e:
            logger.warning(f"Nacos lookup failed for {service_name}, using fallback: {e}")

    fallback = os.environ.get(fallback_env, "")
    logger.debug(f"Resolved {service_name} -> {fallback} via env fallback")
    return fallback
