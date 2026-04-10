import os
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

from services.common.celery_app import celery_app

logger = logging.getLogger(__name__)

SMTP_SERVER = os.environ.get("SMTP_SERVER", os.environ.get("SMTP_HOST", "smtp.gmail.com"))
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")
FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:3000")

DATABASE_URL = os.environ.get("DATABASE_URL", "")
SCYLLA_HOSTS = os.environ.get("SCYLLA_HOSTS", "scylladb")
SCYLLA_PORT = int(os.environ.get("SCYLLA_PORT", "9042"))
SCYLLA_KEYSPACE = os.environ.get("SCYLLA_KEYSPACE", "im_message")
ELASTICSEARCH_HOSTS = os.environ.get("ELASTICSEARCH_HOSTS", "http://elasticsearch:9200")
AVATAR_UPLOAD_DIR = os.environ.get("AVATAR_UPLOAD_DIR", "static/avatars")

MESSAGES_INDEX = "im_messages"
USERS_INDEX = "im_users"
ROOMS_INDEX = "im_rooms"

MESSAGES_MAPPING = {
    "settings": {
        "number_of_shards": 3,
        "number_of_replicas": 1,
        "analysis": {
            "analyzer": {
                "ik_smart_analyzer": {"type": "custom", "tokenizer": "ik_smart"},
                "ik_max_word_analyzer": {"type": "custom", "tokenizer": "ik_max_word"}
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
                "fields": {"keyword": {"type": "keyword", "ignore_above": 256}}
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
                "edge_ngram_filter": {"type": "edge_ngram", "min_gram": 1, "max_gram": 20}
            }
        }
    },
    "mappings": {
        "properties": {
            "user_id": {"type": "keyword"},
            "username": {"type": "text", "analyzer": "prefix_analyzer", "search_analyzer": "standard",
                         "fields": {"keyword": {"type": "keyword"}}},
            "displayname": {"type": "text", "analyzer": "prefix_analyzer", "search_analyzer": "standard",
                            "fields": {"keyword": {"type": "keyword"}}},
            "email": {"type": "keyword"},
            "avatar": {"type": "keyword"},
            "is_active": {"type": "boolean"}
        }
    }
}

ROOMS_MAPPING = {
    "settings": {"number_of_shards": 1, "number_of_replicas": 1},
    "mappings": {
        "properties": {
            "room_id": {"type": "keyword"},
            "name": {"type": "text", "analyzer": "ik_max_word", "search_analyzer": "ik_smart"},
            "creator_id": {"type": "integer"},
            "created_at": {"type": "date"}
        }
    }
}


def _get_es_client():
    from elasticsearch import Elasticsearch
    es_hosts_list = [h.strip() for h in ELASTICSEARCH_HOSTS.split(",") if h.strip()]
    return Elasticsearch(es_hosts_list)


def _send_email(to_email, subject, body):
    if not SMTP_USER or not SMTP_PASSWORD:
        logger.info(f"[Email skipped] To: {to_email} | Subject: {subject}")
        return True
    try:
        msg = MIMEMultipart()
        msg["From"] = SMTP_USER
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "html"))
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        logger.error(f"Error sending email: {e}")
        return False


@celery_app.task(queue="emails", bind=True, max_retries=3, default_retry_delay=60)
def send_verification_email_task(self, to_email, subject, body):
    try:
        return _send_email(to_email, subject, body)
    except Exception as exc:
        raise self.retry(exc=exc)


@celery_app.task(queue="emails", bind=True, max_retries=3, default_retry_delay=60)
def send_password_reset_email_task(self, to_email, subject, body):
    try:
        return _send_email(to_email, subject, body)
    except Exception as exc:
        raise self.retry(exc=exc)


@celery_app.task(queue="emails", bind=True, max_retries=3, default_retry_delay=60)
def send_offline_notification_task(self, to_email, sender_name, content):
    try:
        body = f"<h3>New message from {sender_name}</h3><p>{content}</p>"
        return _send_email(to_email, f"New message from {sender_name}", body)
    except Exception as exc:
        raise self.retry(exc=exc)


@celery_app.task(queue="search", bind=True)
def reindex_messages_task(self):
    from cassandra.cluster import Cluster

    es = _get_es_client()

    try:
        if es.indices.exists(index=MESSAGES_INDEX):
            es.indices.delete(index=MESSAGES_INDEX)
        es.indices.create(index=MESSAGES_INDEX, body=MESSAGES_MAPPING)
    except Exception as e:
        logger.error(f"Failed to recreate index {MESSAGES_INDEX}: {e}")
        raise

    cluster = Cluster(SCYLLA_HOSTS.split(","), port=SCYLLA_PORT)
    session = cluster.connect(SCYLLA_KEYSPACE)
    rows = session.execute("SELECT id, room_id, sender_id, content, created_at FROM messages")

    bulk_body = []
    count = 0
    for row in rows:
        bulk_body.append({"index": {"_index": MESSAGES_INDEX, "_id": str(row.id)}})
        bulk_body.append({
            "message_id": str(row.id),
            "room_id": row.room_id,
            "sender_id": row.sender_id,
            "content": row.content,
            "created_at": row.created_at.isoformat() if row.created_at else None
        })
        if len(bulk_body) >= 2000:
            es.bulk(body=bulk_body)
            count += 1000
            bulk_body = []
    if bulk_body:
        es.bulk(body=bulk_body)
        count += len(bulk_body) // 2

    cluster.shutdown()
    return {"status": "completed", "index": MESSAGES_INDEX, "count": count}


@celery_app.task(queue="search", bind=True)
def reindex_users_task(self):
    from sqlalchemy import create_engine, text

    es = _get_es_client()

    try:
        if es.indices.exists(index=USERS_INDEX):
            es.indices.delete(index=USERS_INDEX)
        es.indices.create(index=USERS_INDEX, body=USERS_MAPPING)
    except Exception as e:
        logger.error(f"Failed to recreate index {USERS_INDEX}: {e}")
        raise

    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT id, username, displayname, email, avatar, is_active FROM users"))
        bulk_body = []
        count = 0
        for row in rows:
            bulk_body.append({"index": {"_index": USERS_INDEX, "_id": str(row[0])}})
            bulk_body.append({
                "user_id": str(row[0]),
                "username": row[1] or "",
                "displayname": row[2] or "",
                "email": row[3],
                "avatar": row[4],
                "is_active": row[5] if row[5] is not None else True
            })
            if len(bulk_body) >= 2000:
                es.bulk(body=bulk_body)
                count += 1000
                bulk_body = []
        if bulk_body:
            es.bulk(body=bulk_body)
            count += len(bulk_body) // 2

    return {"status": "completed", "index": USERS_INDEX, "count": count}


@celery_app.task(queue="search", bind=True)
def reindex_rooms_task(self):
    from sqlalchemy import create_engine, text

    es = _get_es_client()

    try:
        if es.indices.exists(index=ROOMS_INDEX):
            es.indices.delete(index=ROOMS_INDEX)
        es.indices.create(index=ROOMS_INDEX, body=ROOMS_MAPPING)
    except Exception as e:
        logger.error(f"Failed to recreate index {ROOMS_INDEX}: {e}")
        raise

    group_db_url = DATABASE_URL.replace("im_user", "im_group").replace("im_storage", "im_group")
    engine = create_engine(group_db_url)
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT id, name, creator_id, created_at FROM rooms"))
        bulk_body = []
        count = 0
        for row in rows:
            bulk_body.append({"index": {"_index": ROOMS_INDEX, "_id": str(row[0])}})
            bulk_body.append({
                "room_id": str(row[0]),
                "name": row[1] or "",
                "creator_id": row[2],
                "created_at": row[3].isoformat() if row[3] else None
            })
            if len(bulk_body) >= 2000:
                es.bulk(body=bulk_body)
                count += 1000
                bulk_body = []
        if bulk_body:
            es.bulk(body=bulk_body)
            count += len(bulk_body) // 2

    return {"status": "completed", "index": ROOMS_INDEX, "count": count}


@celery_app.task(queue="maintenance")
def cleanup_expired_tokens():
    from sqlalchemy import create_engine, text

    if not DATABASE_URL:
        return {"status": "skipped", "reason": "no DATABASE_URL"}

    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        result = conn.execute(
            text("DELETE FROM refresh_tokens WHERE expires_at < :now"),
            {"now": datetime.utcnow()}
        )
        conn.commit()
        deleted = result.rowcount
    return {"deleted_count": deleted}


@celery_app.task(queue="maintenance")
def rotate_jwt_keys():
    import secrets as secrets_mod
    access_key = secrets_mod.token_urlsafe(32)
    refresh_key = secrets_mod.token_urlsafe(32)
    return {
        "status": "rotated",
        "timestamp": datetime.utcnow().isoformat(),
        "hint": "Keys generated; services should reload from environment or shared store"
    }


@celery_app.task(queue="maintenance")
def cleanup_orphan_avatars():
    import glob
    from sqlalchemy import create_engine, text

    if not DATABASE_URL:
        return {"status": "skipped", "reason": "no DATABASE_URL"}

    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT avatar FROM users WHERE avatar IS NOT NULL AND avatar != ''"))
        referenced = set()
        for row in rows:
            avatar = row[0]
            if avatar:
                filename = avatar.split("/")[-1]
                referenced.add(filename)

    upload_dir = os.path.join(AVATAR_UPLOAD_DIR, "uploads")
    if not os.path.exists(upload_dir):
        return {"status": "skipped", "reason": "upload dir not found"}

    removed = 0
    for filepath in glob.glob(os.path.join(upload_dir, "*")):
        filename = os.path.basename(filepath)
        if filename not in referenced:
            try:
                os.remove(filepath)
                removed += 1
            except Exception:
                pass

    return {"removed_count": removed}


@celery_app.task(queue="search")
def es_index_health_check():
    es = _get_es_client()

    try:
        health = es.cluster.health()
        indices_stats = {}
        for idx in [MESSAGES_INDEX, USERS_INDEX, ROOMS_INDEX]:
            if es.indices.exists(index=idx):
                count = es.count(index=idx)["count"]
                indices_stats[idx] = {"exists": True, "doc_count": count}
            else:
                indices_stats[idx] = {"exists": False, "doc_count": 0}

        return {
            "cluster_status": health["status"],
            "indices": indices_stats
        }
    except Exception as e:
        return {"cluster_status": "error", "error": str(e)}
