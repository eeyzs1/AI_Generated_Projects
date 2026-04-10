from database import get_es_client, MESSAGES_INDEX, USERS_INDEX, ROOMS_INDEX
import logging

logger = logging.getLogger(__name__)


def search_messages(keyword: str, room_id: int = None, from_offset: int = 0, size: int = 20) -> dict:
    es = get_es_client()
    body = {
        "query": {
            "bool": {
                "must": [
                    {
                        "match": {
                            "content": {
                                "query": keyword,
                                "analyzer": "ik_smart"
                            }
                        }
                    }
                ],
                "filter": []
            }
        },
        "highlight": {
            "pre_tags": ["<em>"],
            "post_tags": ["</em>"],
            "fields": {
                "content": {}
            }
        },
        "sort": [
            "_score",
            {"created_at": {"order": "desc"}}
        ],
        "from": from_offset,
        "size": size
    }

    if room_id is not None:
        body["query"]["bool"]["filter"].append({"term": {"room_id": room_id}})

    try:
        resp = es.search(index=MESSAGES_INDEX, body=body)
        total = resp["hits"]["total"]["value"]
        results = []
        for hit in resp["hits"]["hits"]:
            source = hit["_source"]
            highlighted = hit.get("highlight", {}).get("content", [source.get("content", "")])
            results.append({
                "id": source.get("message_id", hit["_id"]),
                "content": highlighted[0] if highlighted else source.get("content", ""),
                "room_id": source.get("room_id"),
                "sender_id": source.get("sender_id"),
                "created_at": source.get("created_at"),
                "sender": None
            })
        return {"total": total, "from_offset": from_offset, "size": size, "results": results}
    except Exception as e:
        logger.error(f"Message search error: {e}")
        return {"total": 0, "from_offset": from_offset, "size": size, "results": []}


def search_users(keyword: str, from_offset: int = 0, size: int = 20) -> dict:
    es = get_es_client()
    body = {
        "query": {
            "bool": {
                "should": [
                    {"match": {"username": {"query": keyword, "analyzer": "standard"}}},
                    {"match": {"displayname": {"query": keyword, "analyzer": "standard"}}}
                ],
                "minimum_should_match": 1
            }
        },
        "from": from_offset,
        "size": size
    }

    try:
        resp = es.search(index=USERS_INDEX, body=body)
        total = resp["hits"]["total"]["value"]
        results = []
        for hit in resp["hits"]["hits"]:
            source = hit["_source"]
            results.append({
                "user_id": source.get("user_id", hit["_id"]),
                "username": source.get("username", ""),
                "displayname": source.get("displayname", ""),
                "email": source.get("email"),
                "avatar": source.get("avatar"),
                "is_active": source.get("is_active")
            })
        return {"total": total, "from_offset": from_offset, "size": size, "results": results}
    except Exception as e:
        logger.error(f"User search error: {e}")
        return {"total": 0, "from_offset": from_offset, "size": size, "results": []}


def search_rooms(keyword: str, from_offset: int = 0, size: int = 20) -> dict:
    es = get_es_client()
    body = {
        "query": {
            "match": {
                "name": {
                    "query": keyword,
                    "analyzer": "ik_smart"
                }
            }
        },
        "from": from_offset,
        "size": size
    }

    try:
        resp = es.search(index=ROOMS_INDEX, body=body)
        total = resp["hits"]["total"]["value"]
        results = []
        for hit in resp["hits"]["hits"]:
            source = hit["_source"]
            results.append({
                "room_id": source.get("room_id", hit["_id"]),
                "name": source.get("name", ""),
                "creator_id": source.get("creator_id"),
                "created_at": source.get("created_at")
            })
        return {"total": total, "from_offset": from_offset, "size": size, "results": results}
    except Exception as e:
        logger.error(f"Room search error: {e}")
        return {"total": 0, "from_offset": from_offset, "size": size, "results": []}


def index_message(message_id: str, room_id: int, sender_id: int, content: str, created_at: str):
    es = get_es_client()
    try:
        es.index(
            index=MESSAGES_INDEX,
            id=message_id,
            body={
                "message_id": message_id,
                "room_id": room_id,
                "sender_id": sender_id,
                "content": content,
                "created_at": created_at
            }
        )
    except Exception as e:
        logger.error(f"Index message error: {e}")


def index_user(user_id: str, username: str, displayname: str, email: str = None,
               avatar: str = None, is_active: bool = True):
    es = get_es_client()
    try:
        es.index(
            index=USERS_INDEX,
            id=user_id,
            body={
                "user_id": user_id,
                "username": username,
                "displayname": displayname,
                "email": email,
                "avatar": avatar,
                "is_active": is_active
            }
        )
    except Exception as e:
        logger.error(f"Index user error: {e}")


def index_room(room_id: str, name: str, creator_id: int = None, created_at: str = None):
    es = get_es_client()
    try:
        es.index(
            index=ROOMS_INDEX,
            id=room_id,
            body={
                "room_id": room_id,
                "name": name,
                "creator_id": creator_id,
                "created_at": created_at
            }
        )
    except Exception as e:
        logger.error(f"Index room error: {e}")
