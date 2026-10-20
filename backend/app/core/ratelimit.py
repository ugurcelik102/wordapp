"""
Kimliksiz (auth'suz) yapay zekâ uçları için kötüye kullanım koruması.

Üyelik kaldırıldığı için bu uçlar herkese açıktır ve her istek Claude'a para
harcatır. İki katmanlı koruma uygulanır:

  1. Cihaz başına günlük kota  — istemcinin gönderdiği zorunlu X-Device-Id başlığı
     (iOS identifierForVendor) ile. Normal kullanıcıyı hiç etkilemez.
  2. IP başına pencere limiti  — cihaz kimliğini rastgele üretip kotayı
     aşmaya çalışan istemciler için emniyet ağı.

Sayaçlar BELLEKTE tutulur: tek instance için yeterlidir, yeniden deploy'da
sıfırlanır. Birden fazla replica'ya çıkılırsa Redis'e taşınmalıdır.
"""
import time
import uuid
from collections import defaultdict

from fastapi import Header, HTTPException, Request

from app.core.config import settings

# device_id -> (gün damgası, sayaç)
_device_hits: dict[str, tuple[int, int]] = {}
# ip -> [zaman damgaları]
_ip_hits: dict[str, list[float]] = defaultdict(list)

_last_prune = 0.0
_PRUNE_INTERVAL_SEC = 300


def _prune(now: float) -> None:
    """Eski kayıtları ara sıra temizler; sözlükler sınırsız büyümesin."""
    global _last_prune
    if now - _last_prune < _PRUNE_INTERVAL_SEC:
        return
    _last_prune = now

    today = int(now // 86400)
    for device_id, (day, _) in list(_device_hits.items()):
        if day != today:
            del _device_hits[device_id]

    cutoff = now - settings.AI_IP_WINDOW_SEC
    for ip, stamps in list(_ip_hits.items()):
        fresh = [t for t in stamps if t > cutoff]
        if fresh:
            _ip_hits[ip] = fresh
        else:
            del _ip_hits[ip]


def _client_ip(request: Request) -> str:
    """Railway gibi proxy'lerin arkasında gerçek istemci IP'si X-Forwarded-For'dadır."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _is_valid_device_id(value: str | None) -> bool:
    if not value or len(value) != 36:
        return False
    try:
        uuid.UUID(value)
    except ValueError:
        return False
    return True


async def ai_quota(
    request: Request,
    x_device_id: str | None = Header(default=None),
) -> None:
    """AI uçlarına takılan bağımlılık: kotayı aşan isteği 429 ile reddeder."""
    # Başlık zorunlu: yoksa cihaz kotası hiç uygulanmaz, yalnızca geniş IP
    # limiti kalırdı. iOS her istekte bir UUID gönderir; biçimi de doğrulanır
    # ki keyfi uzun kimliklerle bellekteki sayaç tablosu şişirilemesin.
    if not _is_valid_device_id(x_device_id):
        raise HTTPException(status_code=400, detail="Geçersiz istemci.")

    now = time.time()
    _prune(now)

    ip = _client_ip(request)
    cutoff = now - settings.AI_IP_WINDOW_SEC
    stamps = [t for t in _ip_hits[ip] if t > cutoff]
    if len(stamps) >= settings.AI_IP_WINDOW_LIMIT:
        raise HTTPException(
            status_code=429,
            detail="Çok fazla istek gönderildi. Lütfen birkaç dakika sonra tekrar deneyin.",
        )
    stamps.append(now)
    _ip_hits[ip] = stamps

    today = int(now // 86400)
    day, count = _device_hits.get(x_device_id, (today, 0))
    if day != today:
        day, count = today, 0
    if count >= settings.AI_DEVICE_DAILY_LIMIT:
        raise HTTPException(
            status_code=429,
            detail="Bugünlük yapay zekâ kullanım hakkın doldu. Yarın tekrar deneyebilirsin.",
        )
    _device_hits[x_device_id] = (day, count + 1)
