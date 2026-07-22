"""
Canlı (Railway) veritabanına YENİ kelime havuzunu ekler — hiçbir şeyi silmez.
Kullanıcı ilerlemesi (user_word_progress, paketler vb.) korunur.
seed_words_v2.sql NOT EXISTS korumalı olduğundan tekrar çalıştırmak güvenlidir.

Kullanım (backend/ dizininde, venv aktifken):
    RAILWAY_DB_URL="postgresql://..." python scripts/apply_seed_v2.py
"""
import asyncio
import os
import sys
from pathlib import Path

import asyncpg

BACKEND_DIR = Path(__file__).resolve().parents[1]


async def main() -> None:
    url = os.environ.get("RAILWAY_DB_URL")
    if not url:
        print("HATA: RAILWAY_DB_URL environment variable'ı boş.")
        sys.exit(1)

    url = url.replace("postgresql+asyncpg://", "postgresql://")

    conn = await asyncpg.connect(url)
    try:
        before = await conn.fetchval("SELECT count(*) FROM words")

        # Havuz eksikse önce extra seed'i de uygula (idempotent değil ama
        # kelime adı kontrolüyle koruyalım: v2 zaten NOT EXISTS korumalı).
        sql = (BACKEND_DIR / "seed_words_v2.sql").read_text()
        await conn.execute(sql)

        after = await conn.fetchval("SELECT count(*) FROM words")
        per_level = await conn.fetch(
            "SELECT level_id, count(*) FROM words GROUP BY level_id ORDER BY level_id"
        )
        print(f"Eklenen kelime: {after - before} (toplam {after})")
        for row in per_level:
            print(f"  seviye {row['level_id']}: {row['count']} kelime")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
