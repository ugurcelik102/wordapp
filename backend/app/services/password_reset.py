"""
Şifre sıfırlama kodları + e-posta gönderimi.

Kodlar bellekte (in-memory) tutulur; kısa ömürlü oldukları için DB şeması
değiştirmeye gerek yoktur. Tek API instance için yeterlidir. API yeniden
başlarsa bekleyen kodlar düşer (kullanıcı yeniden talep eder).

Gönderim tercih sırası:
  1) Brevo HTTP API  — üretim (Railway giden SMTP portlarını engeller)
  2) SMTP            — yerel geliştirme
  3) dev modu        — kod log'a yazılır ve endpoint yanıtında dönülür
"""
import ssl
import smtplib
import secrets
import threading
from email.message import EmailMessage
from datetime import datetime, timedelta, timezone

import httpx

from app.core.config import settings

BREVO_ENDPOINT = "https://api.brevo.com/v3/smtp/email"

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


def brevo_configured() -> bool:
    return bool(settings.BREVO_API_KEY and _sender_email())


def _sender_email() -> str:
    """Gönderen adresi: EMAIL_FROM > SMTP_USER (geriye dönük uyum)."""
    return settings.EMAIL_FROM or settings.SMTP_USER


def _subject() -> str:
    return "Vocabee — Şifre sıfırlama kodu"


def _body(code: str) -> str:
    return (
        f"Şifre sıfırlama kodun: {code}\n\n"
        f"Bu kod {settings.RESET_CODE_TTL_MIN} dakika geçerlidir.\n"
        f"Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin."
    )


def _send_via_brevo(to_email: str, code: str) -> bool:
    """Brevo HTTP API ile gönderir (443 üzerinden — SMTP portu gerekmez)."""
    payload = {
        "sender": {"name": settings.EMAIL_FROM_NAME, "email": _sender_email()},
        "to": [{"email": to_email}],
        "subject": _subject(),
        "textContent": _body(code),
    }
    try:
        resp = httpx.post(
            BREVO_ENDPOINT,
            json=payload,
            headers={
                "api-key": settings.BREVO_API_KEY,
                "content-type": "application/json",
                "accept": "application/json",
            },
            timeout=15,
        )
        if resp.status_code in (200, 201, 202):
            return True
        print(f"[password_reset] Brevo hatası ({to_email}): HTTP {resp.status_code} {resp.text[:300]}")
        return False
    except Exception as e:  # noqa: BLE001
        print(f"[password_reset] Brevo isteği başarısız ({to_email}): {type(e).__name__}: {e}")
        return False


def _send_via_smtp(to_email: str, code: str) -> bool:
    """SMTP ile gönderir. Yerel geliştirme içindir; PaaS'lerde portlar kapalı olabilir."""
    msg = EmailMessage()
    msg["Subject"] = _subject()
    msg["From"] = settings.SMTP_FROM
    msg["To"] = to_email
    msg.set_content(_body(code))

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
        print(f"[password_reset] SMTP gönderilemedi ({to_email}): {type(e).__name__}: {e}")
        return False


def send_reset_email(to_email: str, code: str) -> bool:
    """Kodu e-posta ile gönderir. Hiçbir sağlayıcı yapılandırılmamışsa False döner."""
    if brevo_configured() and _send_via_brevo(to_email, code):
        return True

    if smtp_configured() and _send_via_smtp(to_email, code):
        return True

    if not brevo_configured() and not smtp_configured():
        print(f"[password_reset] E-posta sağlayıcısı yok — {to_email} için kod (dev): {code}")
    return False
