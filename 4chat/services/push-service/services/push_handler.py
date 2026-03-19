import smtplib, os
from email.mime.text import MIMEText

SMTP_HOST = os.environ.get("SMTP_HOST", "")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASS = os.environ.get("SMTP_PASS", "")

async def send_offline_notification(to_email: str, sender_name: str, content: str):
    if not SMTP_HOST or not SMTP_USER:
        return
    try:
        msg = MIMEText(f"{sender_name} sent you a message:\n\n{content}", "plain", "utf-8")
        msg["Subject"] = f"New message from {sender_name}"
        msg["From"] = SMTP_USER
        msg["To"] = to_email
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as s:
            s.starttls()
            s.login(SMTP_USER, SMTP_PASS)
            s.sendmail(SMTP_USER, [to_email], msg.as_string())
    except Exception as e:
        print(f"Email send failed: {e}")
