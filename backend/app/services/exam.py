"""
Genel seviye deneme sınavı üretimi (çoktan seçmeli kelime + gramer).
Kullanıcının CEFR seviyesine göre LLM ile üretilir.
"""
import json
import uuid
import random

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from starlette.concurrency import run_in_threadpool
import anthropic

from app.core.config import settings
from app.models.user import Level, UserProfile


def _build_exam_prompt(level, count: int) -> str:
    return f"""You are creating an English level test for a {level.code} ({level.name}) level learner.

Create {count} multiple-choice questions, MIXED between VOCABULARY and GRAMMAR, all suitable for {level.code} level.
- Vocabulary: choose the correct word to complete a sentence, or the word closest in meaning.
- Grammar: choose the correct verb form/tense, preposition, article, or structure to complete a sentence.

Rules:
- Each question has EXACTLY 4 options, with exactly one correct.
- Keep difficulty appropriate for {level.code}.
- The question and options are in English; the explanation is a SHORT Turkish sentence.

Respond ONLY as a JSON array (no markdown, no extra text). Each item:
{{
  "type": "vocab" | "grammar",
  "question": "a sentence with a blank ____ or a short prompt",
  "options": ["option A", "option B", "option C", "option D"],
  "answer": "the exact text of the correct option",
  "explanation": "kısa Türkçe açıklama"
}}"""


def _generate_sync(prompt: str) -> list[dict]:
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=4000,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = message.content[0].text.strip()
    start, end = raw.find("["), raw.rfind("]")
    if start == -1 or end == -1:
        return []
    return json.loads(raw[start:end + 1])


async def generate_exam(db: AsyncSession, user_id: uuid.UUID, count: int = 20) -> list[dict]:
    if not settings.ANTHROPIC_API_KEY:
        return []

    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = profile_result.scalar_one()
    level_result = await db.execute(select(Level).where(Level.id == profile.current_level_id))
    level = level_result.scalar_one()

    prompt = _build_exam_prompt(level, count)
    try:
        raw_items = await run_in_threadpool(_generate_sync, prompt)
    except Exception:
        return []

    questions: list[dict] = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        q = str(item.get("question", "")).strip()
        options = [str(o).strip() for o in item.get("options", []) if str(o).strip()]
        answer = str(item.get("answer", "")).strip()
        if not q or len(options) < 2 or answer not in options:
            continue
        # 4 şıka tamamla/kırp ve karıştır
        options = options[:4]
        random.shuffle(options)
        qtype = item.get("type") if item.get("type") in ("vocab", "grammar") else "vocab"
        questions.append({
            "type": qtype,
            "question": q,
            "options": options,
            "answer": answer,
            "explanation": (str(item.get("explanation", "")).strip() or None),
        })

    return questions
