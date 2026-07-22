"""
Railway Postgres'i sıfırlayıp schema.sql + seed dosyalarını çalıştırır.

Kullanım (backend/ dizininde, venv aktifken):
    RAILWAY_DB_URL="postgresql://..." python scripts/reset_railway_db.py

RAILWAY_DB_URL: Railway → Postgres servisi → Connect → Public Network
altındaki bağlantı URL'si (postgresql:// ile başlayan, asyncpg değil).
"""
import asyncio
import os
import sys
from pathlib import Path

import asyncpg

REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_DIR = REPO_ROOT / "backend"


async def run_file(conn: asyncpg.Connection, path: Path) -> None:
    print(f"-> {path.relative_to(REPO_ROOT)} çalıştırılıyor...")
    sql = path.read_text()
    await conn.execute(sql)


async def main() -> None:
    url = os.environ.get("RAILWAY_DB_URL")
    if not url:
        print("HATA: RAILWAY_DB_URL environment variable'ı boş.")
        sys.exit(1)

    # asyncpg "postgresql+asyncpg://" değil düz "postgresql://" bekler
    url = url.replace("postgresql+asyncpg://", "postgresql://")

    conn = await asyncpg.connect(url)
    try:
        print("1) Şema sıfırlanıyor...")
        await conn.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")

        print("2) schema.sql çalıştırılıyor...")
        await run_file(conn, REPO_ROOT / "schema.sql")

        print("3) seed_words.sql çalıştırılıyor...")
        await run_file(conn, BACKEND_DIR / "seed_words.sql")

        print("4) seed_words_extra.sql çalıştırılıyor...")
        await run_file(conn, BACKEND_DIR / "seed_words_extra.sql")

        print("5) seed_words_v2.sql çalıştırılıyor...")
        await run_file(conn, BACKEND_DIR / "seed_words_v2.sql")

        print("Bitti.")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
