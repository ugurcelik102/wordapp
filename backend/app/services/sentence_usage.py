"""
'Cümle İçinde Kullanım' modülü için alıştırma üretimi.

Kaynak: bugünkü paket kelimeleri + SRS'te tekrarı gelen kelimeler (karışık).
Her kelime için LLM ile rastgele bir alıştırma üretilir:
  - "order": İngilizce cümle verilir, karışık Türkçe kelimelerle çeviri kurulur.
  - "blank": Türkçe cümle + boşluklu İngilizce cümle, doğru kelime seçilir.
"""
import json
import re
import random
import uuid
from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from starlette.concurrency import run_in_threadpool
import anthropic

from app.core.config import settings
from app.models.word import Word
from app.models.package import WordPackage, WordPackageItem
from app.services.words import get_review_words


def _tokenize(sentence: str) -> list[str]:
    """Cümleyi çipler için kelimelere böler; cümle sonu ve kenar noktalamayı atar."""
    cleaned = sentence.strip().rstrip("?.!")
    toks = [t.strip('.,!?;:"\'') for t in cleaned.split()]
    return [t for t in toks if t]


async def _collect_source_words(db: AsyncSession, user_id: uuid.UUID, limit: int = 10) -> list[Word]:
    """Bugünkü paket + tekrarı gelen kelimeleri toplar, karıştırır, limitler."""
    picked: dict[uuid.UUID, Word] = {}

    today = date.today()
    pkg_res = await db.execute(
        select(WordPackage)
        .where(WordPackage.user_id == user_id, WordPackage.package_date == today)
        .options(selectinload(WordPackage.items).selectinload(WordPackageItem.word))
    )
    pkg = pkg_res.scalar_one_or_none()
    if pkg:
        for item in pkg.items:
            picked[item.word.id] = item.word

    for w in await get_review_words(db, user_id, limit=limit):
        picked[w.id] = w

    pool = list(picked.values())
    random.shuffle(pool)
    return pool[:limit]


def _build_prompt(words: list[Word]) -> str:
    listing = "\n".join(f'- {w.word} ({w.definition_tr or w.definition})' for w in words)
    return f"""You create English practice exercises for a Turkish speaker learning English.
For EACH target word below, create ONE exercise. Randomly pick its "type": "order" or "blank".

Target words:
{listing}

For each word output a JSON object with:
- "word": the exact target English word (as given above)
- "type": "order" or "blank"
- "english": a short, natural English sentence (6-10 words) that uses the target word exactly once
- "turkish": the correct, natural Turkish translation of that sentence
- "distractors_en": for "blank" -> 3 plausible WRONG English words similar to the target; for "order" -> 2 extra English distractor words NOT in the sentence
- "distractors_tr": for "order" -> 2 extra Turkish distractor words that are NOT in the sentence

Rules:
- For "blank", the target word MUST appear in "english" exactly once.
- Keep the language simple and learner-friendly.
- Respond with ONLY a JSON array (no markdown fences, no extra text)."""


def _generate_sync(words: list[Word]) -> list[dict]:
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    msg = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=2500,
        messages=[{"role": "user", "content": _build_prompt(words)}],
    )
    raw = msg.content[0].text.strip()
    start, end = raw.find("["), raw.rfind("]")
    if start == -1 or end == -1:
        return []
    return json.loads(raw[start:end + 1])


async def generate_sentence_exercises(db: AsyncSession, user_id: uuid.UUID) -> list[dict]:
    words = await _collect_source_words(db, user_id, limit=10)
    if not words or not settings.ANTHROPIC_API_KEY:
        return []

    by_text = {w.word.lower(): w for w in words}
    try:
        raw_items = await run_in_threadpool(_generate_sync, words)
    except Exception:
        return []

    exercises: list[dict] = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        word_text = str(item.get("word", "")).strip()
        etype = item.get("type")
        english = str(item.get("english", "")).strip()
        turkish = str(item.get("turkish", "")).strip()
        if not word_text or not english or not turkish:
            continue

        src = by_text.get(word_text.lower())
        word_id = str(src.id) if src else None

        if etype == "order":
            # Türkçe cümle gösterilir, İngilizce kelime çipleriyle İngilizce çeviri kurulur.
            dist_en = [str(d).strip() for d in item.get("distractors_en", []) if str(d).strip()][:2]
            tokens = _tokenize(english)
            if len(tokens) < 2:
                continue
            chips = tokens + dist_en
            random.shuffle(chips)
            exercises.append({
                "type": "order",
                "word": word_text,
                "word_id": word_id,
                "prompt": turkish,
                "prompt_lang": "tr",
                "english": english,
                "turkish": turkish,
                "answer_tokens": tokens,
                "chips": chips,
                "options": None,
                "blank_english": None,
            })

        elif etype == "blank":
            distractors = [str(d).strip() for d in item.get("distractors_en", []) if str(d).strip()][:3]
            if len(distractors) < 1:
                continue
            pattern = re.compile(r'\b' + re.escape(word_text) + r'\b', re.IGNORECASE)
            blank_english, n = pattern.subn("____", english, count=1)
            if n == 0:
                continue
            options = distractors + [word_text]
            random.shuffle(options)
            exercises.append({
                "type": "blank",
                "word": word_text,
                "word_id": word_id,
                "prompt": turkish,
                "prompt_lang": "tr",
                "english": english,
                "turkish": turkish,
                "answer_tokens": None,
                "chips": None,
                "options": options,
                "blank_english": blank_english,
            })

    random.shuffle(exercises)
    return exercises
