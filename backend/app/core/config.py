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

    # E-posta (şifre sıfırlama). Boşsa "dev modu": kod gönderilmez, log'a yazılır.
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
