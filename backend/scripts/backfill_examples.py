"""
Tek seferlik toplu örnek cümle üretimi.

Örnek cümlesi olmayan tüm aktif kelimeler için LLM ile bir örnek cümle + Türkçe
çeviri üretir ve DB'ye kaydeder. Böylece ilk öğrenme oturumunda bekleme olmaz.

Çalıştırma (backend dizininde, venv veya docker içinde):
    python -m scripts.backfill_examples
    # ya da
    python scripts/backfill_examples.py
    # docker ile:
    docker exec -it wordapp_api python scripts/backfill_examples.py

Not: backend/.env içinde ANTHROPIC_API_KEY dolu olmalı.
İstediğin zaman tekrar çalıştırabilirsin; sadece örneği eksik kelimeleri işler.
"""
import asyncio
import os
import sys

# Dosya olarak çalıştırıldığında 'app' paketini bulabilmek için backend kökünü ekle
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.db.session import AsyncSessionLocal
from app.models.word import Word
from app.services.words import ensure_word_example


async def main() -> None:
    if not settings.ANTHROPIC_API_KEY:
        print("HATA: ANTHROPIC_API_KEY tanımlı değil (backend/.env). Üretim yapılamaz.")
        sys.exit(1)

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(Word)
            .where(Word.is_active == True)  # noqa: E712
            .options(selectinload(Word.examples))
            .order_by(Word.frequency_rank.nullslast())
        )
        words = [w for w in result.scalars().all() if not w.examples]

        total = len(words)
        print(f"Örnek cümlesi olmayan {total} aktif kelime bulundu.")
        if total == 0:
            print("Yapılacak bir şey yok. Tüm kelimelerde örnek mevcut.")
            return

        ok = 0
        fail = 0
        for i, word in enumerate(words, 1):
            try:
                before = len(word.examples)
                await ensure_word_example(db, word)
                if len(word.examples) > before:
                    ok += 1
                    mark = "✓"
                else:
                    fail += 1
                    mark = "✗ (üretilemedi)"
            except Exception as e:  # noqa: BLE001
                fail += 1
                mark = f"✗ ({type(e).__name__}: {e})"
            print(f"[{i}/{total}] {word.word:<22} {mark}")

        print(f"\nBitti. Başarılı: {ok}  |  Başarısız: {fail}")


if __name__ == "__main__":
    asyncio.run(main())
