from celery import Celery
from celery.schedules import crontab
import os

CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://redis:6379/1")
CELERY_RESULT_BACKEND = os.environ.get("CELERY_RESULT_BACKEND", "redis://redis:6379/2")

celery_app = Celery(
    "4chat",
    broker=CELERY_BROKER_URL,
    backend=CELERY_RESULT_BACKEND,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_routes={
        "services.common.celery_tasks.send_verification_email_task": {"queue": "emails"},
        "services.common.celery_tasks.send_password_reset_email_task": {"queue": "emails"},
        "services.common.celery_tasks.send_offline_notification_task": {"queue": "emails"},
        "services.common.celery_tasks.reindex_messages_task": {"queue": "search"},
        "services.common.celery_tasks.reindex_users_task": {"queue": "search"},
        "services.common.celery_tasks.reindex_rooms_task": {"queue": "search"},
        "services.common.celery_tasks.cleanup_expired_pending_registrations": {"queue": "maintenance"},
        "services.common.celery_tasks.cleanup_expired_tokens": {"queue": "maintenance"},
        "services.common.celery_tasks.rotate_jwt_keys": {"queue": "maintenance"},
        "services.common.celery_tasks.cleanup_orphan_avatars": {"queue": "maintenance"},
        "services.common.celery_tasks.es_index_health_check": {"queue": "search"},
    },
    beat_schedule={
        "cleanup-expired-pending-registrations": {
            "task": "services.common.celery_tasks.cleanup_expired_pending_registrations",
            "schedule": crontab(minute="*/30"),
        },
        "cleanup-expired-tokens": {
            "task": "services.common.celery_tasks.cleanup_expired_tokens",
            "schedule": crontab(hour=3, minute=0),
        },
        "rotate-jwt-keys": {
            "task": "services.common.celery_tasks.rotate_jwt_keys",
            "schedule": crontab(hour=0, minute=0),
        },
        "cleanup-orphan-avatars": {
            "task": "services.common.celery_tasks.cleanup_orphan_avatars",
            "schedule": crontab(day_of_week=0, hour=4, minute=0),
        },
        "es-index-health-check": {
            "task": "services.common.celery_tasks.es_index_health_check",
            "schedule": crontab(minute="*/30"),
        },
    },
)

celery_app.autodiscover_tasks()
