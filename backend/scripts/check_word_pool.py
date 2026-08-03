"""
SADECE OKUR — hiçbir şeyi değiştirmez.

Canlı veritabanındaki kelime havuzunu ve (istenirse) bir kullanıcının
"görülmemiş kelime" sayısını raporlar. "Her gün aynı kelimeler geliyor"
şikayetinin sebebinin havuzun tükenmesi olup olmadığını gösterir.

Kullanım (backend/ dizininde, venv aktifken):
    RAILWAY_DB_URL="postgresql://..." python3 scripts/check_word_pool.py
    RAILWAY_DB_URL="postgresql://..." python3 scripts/check_word_pool.py ugurcelik102@gmail.com
"""
import asyncio
import os
import sys

import asyncpg


async def main() -> None:
    url = os.environ.get("RAILWAY_DB_URL")
    if not url:
        print("HATA: RAILWAY_DB_URL environment variable'ı boş.")
        sys.exit(1)

    url = url.replace("postgresql+asyncpg://", "postgresql://")
    email = sys.argv[1] if len(sys.argv) > 1 else None

    conn = await asyncpg.connect(url)
    try:
        total = await conn.fetchval("SELECT count(*) FROM words WHERE is_active")
        print(f"Toplam aktif kelime: {total}")
        print("\nSeviye başına:")
        for row in await conn.fetch(
            "SELECT level_id, count(*) AS c FROM words WHERE is_active "
            "GROUP BY level_id ORDER BY level_id"
        ):
            print(f"  seviye {row['level_id']}: {row['c']}")

        if not email:
            print("\n(Kullanıcı bazlı rapor için e-posta adresini argüman olarak ver.)")
            return

        user = await conn.fetchrow(
            "SELECT u.id, p.current_level_id, p.daily_word_count "
            "FROM users u LEFT JOIN user_profiles p ON p.user_id = u.id "
            "WHERE u.email = $1",
            email,
        )
        if not user:
            print(f"\n{email} bulunamadı.")
            return

        print(
            f"\n{email} — seviye {user['current_level_id']}, "
            f"günlük {user['daily_word_count']} kelime"
        )
        print("Görülmemiş kelime sayısı (seviye başına):")
        for row in await conn.fetch(
            "SELECT w.level_id, count(*) AS c FROM words w "
            "WHERE w.is_active AND NOT EXISTS ("
            "  SELECT 1 FROM user_word_progress p "
            "  WHERE p.user_id = $1 AND p.word_id = w.id) "
            "GROUP BY w.level_id ORDER BY w.level_id",
            user["id"],
        ):
            print(f"  seviye {row['level_id']}: {row['c']}")

        unseen_total = await conn.fetchval(
            "SELECT count(*) FROM words w WHERE w.is_active AND NOT EXISTS ("
            "  SELECT 1 FROM user_word_progress p "
            "  WHERE p.user_id = $1 AND p.word_id = w.id)",
            user["id"],
        )
        seen_total = await conn.fetchval(
            "SELECT count(*) FROM user_word_progress WHERE user_id = $1", user["id"]
        )
        print(f"\nToplam görülmemiş: {unseen_total} | daha önce sunulmuş: {seen_total}")
        if unseen_total == 0:
            print(">> Havuz tükenmiş. Her gün aynı kelimelerin gelmesinin sebebi bu.")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
