import os

SMTP_HOST = os.environ.get("SMTP_HOST", "")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASS = os.environ.get("SMTP_PASS", "")


def send_offline_notification(to_email: str, sender_name: str, content: str):
    from services.common.celery_tasks import send_offline_notification_task
    send_offline_notification_task.delay(to_email, sender_name, content)
