from elasticsearch import Elasticsearch
from elasticsearch.exceptions import ConnectionError as ESConnectionError
import os, logging

logger = logging.getLogger(__name__)

ES_HOSTS = os.environ.get("ELASTICSEARCH_HOSTS", "http://elasticsearch:9200")
es_hosts_list = [h.strip() for h in ES_HOSTS.split(",") if h.strip()]

_es_client = None

MESSAGES_INDEX = "im_messages"
USERS_INDEX = "im_users"
ROOMS_INDEX = "im_rooms"

MESSAGES_MAPPING = {
    "settings": {
        "number_of_shards": 3,
        "number_of_replicas": 1,
        "analysis": {
            "analyzer": {
                "ik_smart_analyzer": {
                    "type": "custom",
                    "tokenizer": "ik_smart"
                },
                "ik_max_word_analyzer": {
                    "type": "custom",
                    "tokenizer": "ik_max_word"
                }
            }
        }
    },
    "mappings": {
        "properties": {
            "message_id": {"type": "keyword"},
            "room_id": {"type": "integer"},
            "sender_id": {"type": "integer"},
            "content": {
                "type": "text",
                "analyzer": "ik_max_word_analyzer",
                "search_analyzer": "ik_smart_analyzer",
                "fields": {
                    "keyword": {"type": "keyword", "ignore_above": 256}
                }
            },
            "created_at": {"type": "date"}
        }
    }
}

USERS_MAPPING = {
    "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 1,
        "analysis": {
            "analyzer": {
                "prefix_analyzer": {
                    "type": "custom",
                    "tokenizer": "standard",
                    "filter": ["lowercase", "edge_ngram_filter"]
                }
            },
            "filter": {
                "edge_ngram_filter": {
                    "type": "edge_ngram",
                    "min_gram": 1,
                    "max_gram": 20
                }
            }
        }
    },
    "mappings": {
        "properties": {
            "user_id": {"type": "keyword"},
            "username": {
                "type": "text",
                "analyzer": "prefix_analyzer",
                "search_analyzer": "standard",
                "fields": {
                    "keyword": {"type": "keyword"}
                }
            },
            "displayname": {
                "type": "text",
                "analyzer": "prefix_analyzer",
                "search_analyzer": "standard",
                "fields": {
                    "keyword": {"type": "keyword"}
                }
            },
            "email": {"type": "keyword"},
            "avatar": {"type": "keyword"},
            "is_active": {"type": "boolean"}
        }
    }
}

ROOMS_MAPPING = {
    "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 1
    },
    "mappings": {
        "properties": {
            "room_id": {"type": "keyword"},
            "name": {
                "type": "text",
                "analyzer": "ik_max_word",
                "search_analyzer": "ik_smart"
            },
            "creator_id": {"type": "integer"},
            "created_at": {"type": "date"}
        }
    }
}


def get_es_client() -> Elasticsearch:
    global _es_client
    if _es_client is None:
        _es_client = Elasticsearch(es_hosts_list)
    return _es_client


def init_indices():
    es = get_es_client()
    for index_name, mapping in [
        (MESSAGES_INDEX, MESSAGES_MAPPING),
        (USERS_INDEX, USERS_MAPPING),
        (ROOMS_INDEX, ROOMS_MAPPING),
    ]:
        try:
            if not es.indices.exists(index=index_name):
                es.indices.create(index=index_name, body=mapping)
                logger.info(f"Created ES index: {index_name}")
            else:
                logger.info(f"ES index already exists: {index_name}")
        except ESConnectionError as e:
            logger.error(f"ES connection error while creating index {index_name}: {e}")
        except Exception as e:
            logger.warning(f"Failed to create ES index {index_name}: {e}")
