"""
Şifre sıfırlama kodları + e-posta gönderimi.

Kodlar bellekte (in-memory) tutulur; kısa ömürlü oldukları için DB şeması
değiştirmeye gerek yoktur. Tek API instance için yeterlidir. API yeniden
başlarsa bekleyen kodlar düşer (kullanıcı yeniden talep eder).

SMTP yapılandırılmamışsa "dev modu": e-posta gönderilmez, kod log'a yazılır ve
endpoint tarafından yanıtta dönülür (yalnızca geliştirme kolaylığı için).
"""
import ssl
import smtplib
import secrets
import threading
from email.message import EmailMessage
from datetime import datetime, timedelta, timezone

from app.core.config import settings

_lock = threading.Lock()
# email(lower) -> (code, expires_at)
_codes: dict[str, tuple[str, datetime]] = {}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def generate_code(email: str) -> str:
    """6 haneli kod üretir ve saklar (TTL ile)."""
    code = f"{secrets.randbelow(1_000_000):06d}"
    expires = _now() + timedelta(minutes=settings.RESET_CODE_TTL_MIN)
    with _lock:
        _codes[email.lower()] = (code, expires)
    return code


def verify_code(email: str, code: str) -> bool:
    """Kodu doğrular; doğruysa tüketir (tek kullanımlık)."""
    key = email.lower()
    with _lock:
        entry = _codes.get(key)
        if not entry:
            return False
        saved, expires = entry
        if _now() > expires:
            _codes.pop(key, None)
            return False
        if not secrets.compare_digest(saved, code.strip()):
            return False
        _codes.pop(key, None)
        return True


def smtp_configured() -> bool:
    return bool(settings.SMTP_HOST and settings.SMTP_USER and settings.SMTP_PASSWORD)


def send_reset_email(to_email: str, code: str) -> bool:
    """Kodu e-posta ile gönderir. SMTP yoksa gönderim yapmaz (False döner)."""
    if not smtp_configured():
        print(f"[password_reset] SMTP yok — {to_email} için kod (dev): {code}")
        return False

    msg = EmailMessage()
    msg["Subject"] = "WordApp — Şifre sıfırlama kodu"
    msg["From"] = settings.SMTP_FROM
    msg["To"] = to_email
    msg.set_content(
        f"Şifre sıfırlama kodun: {code}\n\n"
        f"Bu kod {settings.RESET_CODE_TTL_MIN} dakika geçerlidir.\n"
        f"Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin."
    )

    try:
        if settings.SMTP_TLS:
            context = ssl.create_default_context()
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
                server.starttls(context=context)
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                server.send_message(msg)
        else:
            with smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                server.send_message(msg)
        return True
    except Exception as e:  # noqa: BLE001
        print(f"[password_reset] E-posta gönderilemedi ({to_email}): {type(e).__name__}: {e}")
        return False
