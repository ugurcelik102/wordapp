from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import List


class Settings(BaseSettings):
    PROJECT_NAME: str = "WordApp API"
    VERSION: str = "0.1.0"
    API_V1_STR: str = "/api/v1"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://wordapp_user:wordapp_pass@localhost:5432/wordapp"

    @field_validator("DATABASE_URL")
    @classmethod
    def _use_asyncpg_driver(cls, v: str) -> str:
        # Railway/Heroku gibi platformlar DATABASE_URL'i "postgresql://" ya da
        # "postgres://" şemasıyla sağlar; asyncpg sürücüsü için şemayı zorluyoruz.
        if v.startswith("postgres://"):
            return "postgresql+asyncpg://" + v[len("postgres://"):]
        if v.startswith("postgresql://"):
            return "postgresql+asyncpg://" + v[len("postgresql://"):]
        return v

    # Auth
    SECRET_KEY: str = "change-me-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 gün

    # CORS
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000"]

    # AI
    ANTHROPIC_API_KEY: str = ""

    # Kimliksiz AI uçları için kötüye kullanım koruması (bkz. core/ratelimit.py).
    # Cihaz başına günlük istek hakkı; normal bir kullanıcı günde ~10-15 kullanır.
    AI_DEVICE_DAILY_LIMIT: int = 60
    # IP başına pencere: cihaz kimliğini rastgele üretenlere karşı emniyet ağı.
    # DİKKAT: mobil operatörler CGNAT kullandığı için yüzlerce gerçek kullanıcı
    # aynı IP'den çıkabilir. Bu yüzden limit bilerek yüksek tutulur; asıl
    # kontrol cihaz başına kotadır, bu yalnızca tek kaynaklı seli keser.
    AI_IP_WINDOW_SEC: int = 600
    AI_IP_WINDOW_LIMIT: int = 300

    # E-posta (şifre sıfırlama).
    #
    # Tercih sırası: 1) Brevo HTTP API  2) SMTP  3) dev modu (kod log'a yazılır).
    #
    # Railway gibi PaaS'ler giden SMTP portlarını (25/465/587/2525) engellediği
    # için üretimde HTTP API kullanılır; SMTP yalnızca yerel geliştirme içindir.
    BREVO_API_KEY: str = ""
    # Gönderen adresi Brevo'da "doğrulanmış gönderen" olmalıdır.
    EMAIL_FROM: str = ""
    EMAIL_FROM_NAME: str = "Vocabee"

    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = "WordApp <no-reply@wordapp.local>"
    SMTP_TLS: bool = True

    # Şifre sıfırlama kodu geçerlilik süresi (dakika)
    RESET_CODE_TTL_MIN: int = 15

    # Giriş hatalarında ayrıntı: True ise "hesap yok"/"şifre yanlış" ayrı ayrı
    # gösterilir (dev kolaylığı); False ise tek tip "e-posta veya şifre hatalı"
    # (üretim için güvenli — e-posta enumeration'ı engeller).
    DETAILED_AUTH_ERRORS: bool = False

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

# Railway/Heroku genelde 'postgres://' veya 'postgresql://' verir; SQLAlchemy'nin
# async motoru için '+asyncpg' sürücüsüne normalize et.
_db_url = settings.DATABASE_URL
if _db_url.startswith("postgres://"):
    settings.DATABASE_URL = "postgresql+asyncpg://" + _db_url[len("postgres://"):]
elif _db_url.startswith("postgresql://"):
    settings.DATABASE_URL = "postgresql+asyncpg://" + _db_url[len("postgresql://"):]
