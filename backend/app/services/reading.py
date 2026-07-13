import uuid
import anthropic
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models.session import Session
from app.models.package import WordPackage, WordPackageItem
from app.models.word import Word
from app.models.user import Level, UserProfile
from app.models.progress import UserWordProgress
from app.models.reading import ReadingPassage

import re
import json

# Seviyeye özel pedagojik yönergeler (CEFR)
_LEVEL_GUIDANCE = {
    "A1": "Use very short, simple sentences (about 6-8 words). Only present simple tense. Only the most common everyday words. No relative or subordinate clauses.",
    "A2": "Use short, simple sentences (about 8-10 words). Present and past simple and 'going to' future. Common connectors (and, but, because, so). Everyday high-frequency vocabulary.",
    "B1": "Use clear sentences of moderate length (up to ~15 words). Present, past and future, and present perfect. Simple relative clauses (who, which, that) and common phrasal verbs. Familiar everyday topics.",
    "B2": "Use varied sentences with some complexity. All common tenses, conditionals, passive voice, and subordinate clauses. Some idiomatic and topic-specific vocabulary.",
    "C1": "Use complex, well-structured sentences with advanced grammar, nuanced and less common vocabulary, and clear cohesive devices.",
    "C2": "Use sophisticated, near-native language: complex structures, precise and idiomatic vocabulary, and subtle nuance.",
}

# Seviyeye göre ortalama cümle uzunluğu üst sınırı (okunabilirlik kontrolü için)
_LEVEL_MAX_SENTENCE_LEN = {"A1": 9, "A2": 12, "B1": 16, "B2": 22, "C1": 30, "C2": 40}


def _level_guidance(code: str) -> str:
    return _LEVEL_GUIDANCE.get(code, _LEVEL_GUIDANCE["B1"])


def _avg_sentence_length(text: str) -> float:
    sentences = [s for s in re.split(r"[.!?]+", text) if s.strip()]
    words = [w for w in text.split() if w.strip()]
    if not sentences:
        return float(len(words))
    return len(words) / len(sentences)


def _generate_text(prompt: str, model_name: str, max_tokens: int) -> str:
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    message = client.messages.create(
        model=model_name,
        max_tokens=max_tokens,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text.strip()


def _output_format_instruction() -> str:
    return (
        "\n\nRespond ONLY as JSON (no markdown, no extra text) in exactly this shape:\n"
        "{\n"
        '  "passage": "the reading text; keep line breaks for dialogue lines",\n'
        '  "glossary": [ {"word": "<a harder English word or phrase from the passage>", "tr": "<short simple Turkish meaning>"} ]\n'
        "}\n"
        "The glossary must contain 5-8 of the more difficult words or phrases from the passage "
        "at this level, each with a short, simple Turkish meaning."
    )


def _parse_reading_json(raw: str) -> tuple[str, list[dict]]:
    start, end = raw.find("{"), raw.rfind("}")
    if start == -1 or end == -1:
        return raw.strip(), []
    try:
        data = json.loads(raw[start:end + 1])
    except Exception:
        return raw.strip(), []
    passage = str(data.get("passage", "")).strip() or raw.strip()
    glossary: list[dict] = []
    for item in (data.get("glossary") or []):
        if isinstance(item, dict):
            w = str(item.get("word", "")).strip()
            tr = str(item.get("tr", "")).strip()
            if w and tr:
                glossary.append({"word": w, "tr": tr})
    return passage, glossary


def _generate_reading(prompt: str, level_code: str, model_name: str, max_tokens: int) -> tuple[str, list[dict]]:
    """Metni + mini sözlükçeyi üretir; cümleler seviyeye göre fazla uzunsa bir kez sadeleştirir."""
    passage, glossary = _parse_reading_json(_generate_text(prompt, model_name, max_tokens))
    max_len = _LEVEL_MAX_SENTENCE_LEN.get(level_code, 16)
    if _avg_sentence_length(passage) > max_len * 1.4:
        simpler = prompt + (
            f"\n\nIMPORTANT: Your previous version was too hard for this level. "
            f"Rewrite with SHORTER, SIMPLER sentences (under {max_len} words each), "
            f"returning the SAME JSON shape."
        )
        passage, glossary = _parse_reading_json(_generate_text(simpler, model_name, max_tokens))
    return passage, glossary


def _build_reading_prompt(level, words) -> str:
    word_list = "\n".join(
        f"- {w.word} ({w.part_of_speech or 'word'}): {w.definition}" for w in words
    )
    return f"""You are an English language teacher creating a reading passage for a student at {level.code} ({level.name}) level.

Create a short, engaging reading passage (150-200 words) that naturally uses ALL of the following words:

{word_list}

Level guidance for {level.code}: {_level_guidance(level.code)}

Requirements:
- The passage must be appropriate for {level.code} level English learners
- Each target word must appear at least once, used naturally in context
- The story should be coherent and interesting (a short story, anecdote, or descriptive piece)
- Do NOT bold or highlight the target words
{_output_format_instruction()}"""


async def generate_reading_from_learned(
    db: AsyncSession, user_id: uuid.UUID, limit: int = 8
) -> dict:
    """Kullanıcının öğrendiği kelimelerden okuma parçası üretir (kalıcı kaydetmez)."""
    words_result = await db.execute(
        select(Word)
        .join(UserWordProgress, UserWordProgress.word_id == Word.id)
        .where(
            UserWordProgress.user_id == user_id,
            UserWordProgress.status.in_(["learning", "review", "mastered"]),
        )
        .order_by(UserWordProgress.last_reviewed_at.desc().nullslast())
        .limit(limit)
    )
    words = list(words_result.scalars().all())
    if not words:
        raise ValueError("Henüz öğrenilen kelime yok. Önce birkaç kelime çalış.")

    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = profile_result.scalar_one()
    level_result = await db.execute(select(Level).where(Level.id == profile.current_level_id))
    level = level_result.scalar_one()

    prompt = _build_reading_prompt(level, words)
    model_name = "claude-haiku-4-5-20251001"
    content, glossary = _generate_reading(prompt, level.code, model_name, max_tokens=500)
    return {
        "content": content,
        "word_count": len(content.split()),
        "target_words": [w.id for w in words],
        "target_word_texts": [w.word for w in words],
        "model_used": model_name,
        "glossary": glossary,
    }


async def generate_reading_from_review(
    db: AsyncSession, user_id: uuid.UUID
) -> dict:
    """Tekrar zamanı gelen kelimelerden okuma parçası üretir.
    Tekrar kelimesi yoksa öğrenilen kelimelerle fallback yapar."""
    from app.services.words import get_review_words
    words = await get_review_words(db, user_id, limit=8)
    if not words:
        # Fallback: son öğrenilen kelimelerden üret
        words_result = await db.execute(
            select(Word)
            .join(UserWordProgress, UserWordProgress.word_id == Word.id)
            .where(
                UserWordProgress.user_id == user_id,
                UserWordProgress.status.in_(["learning", "review", "mastered"]),
            )
            .order_by(UserWordProgress.last_reviewed_at.desc().nullslast())
            .limit(8)
        )
        words = list(words_result.scalars().all())
    if not words:
        raise ValueError("Henüz öğrenilen kelime yok. Önce birkaç kelime çalış.")

    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = profile_result.scalar_one()
    level_result = await db.execute(select(Level).where(Level.id == profile.current_level_id))
    level = level_result.scalar_one()

    prompt = _build_reading_prompt(level, words)
    model_name = "claude-haiku-4-5-20251001"
    content, glossary = _generate_reading(prompt, level.code, model_name, max_tokens=500)
    return {
        "content": content,
        "word_count": len(content.split()),
        "target_words": [w.id for w in words],
        "target_word_texts": [w.word for w in words],
        "model_used": model_name,
        "glossary": glossary,
    }


def _build_topic_prompt(level, topic: str, as_dialogue: bool) -> str:
    if as_dialogue:
        form = (
            "Write it as a natural, realistic back-and-forth DIALOGUE between two people. "
            "Label the speakers (for example 'A:' and 'B:'), with 6-10 short exchanges."
        )
    else:
        form = "Write it as a short, engaging passage of 120-180 words."
    return f"""You are an English teacher creating reading material for a {level.code} ({level.name}) level learner.

Topic / scenario: {topic}

{form}

Level guidance for {level.code}: {_level_guidance(level.code)}

Requirements:
- Use simple, clear language appropriate for {level.code} level English learners.
- Make it realistic and useful for real everyday situations.
{_output_format_instruction()}"""


async def generate_reading_from_topic(
    db: AsyncSession, user_id: uuid.UUID, topic: str, as_dialogue: bool = True
) -> dict:
    """Belirli bir konu/senaryo hakkında (isteğe bağlı diyalog) okuma parçası üretir."""
    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = profile_result.scalar_one()
    level_result = await db.execute(select(Level).where(Level.id == profile.current_level_id))
    level = level_result.scalar_one()

    prompt = _build_topic_prompt(level, topic, as_dialogue)
    model_name = "claude-haiku-4-5-20251001"
    content, glossary = _generate_reading(prompt, level.code, model_name, max_tokens=700)
    return {
        "content": content,
        "word_count": len(content.split()),
        "target_words": [],
        "target_word_texts": [],
        "model_used": model_name,
        "glossary": glossary,
    }


async def generate_reading_passage(
    db: AsyncSession,
    session_id: uuid.UUID,
    user_id: uuid.UUID,
) -> ReadingPassage:
    """
    Session'daki kelimeleri kullanarak Claude API ile okuma parçası üretir.
    """
    # Mevcut parça var mı?
    existing = await db.execute(
        select(ReadingPassage).where(ReadingPassage.session_id == session_id)
    )
    existing_passage = existing.scalar_one_or_none()
    if existing_passage:
        return existing_passage

    # Session → package → kelimeler
    session_result = await db.execute(
        select(Session).where(Session.id == session_id, Session.user_id == user_id)
    )
    session = session_result.scalar_one_or_none()
    if not session:
        raise ValueError("Session bulunamadı")

    package_result = await db.execute(
        select(WordPackage)
        .where(WordPackage.id == session.package_id)
        .options(selectinload(WordPackage.items).selectinload(WordPackageItem.word))
    )
    package = package_result.scalar_one()
    words = [item.word for item in package.items]

    # Kullanıcı seviyesi
    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = profile_result.scalar_one()
    level_result = await db.execute(select(Level).where(Level.id == profile.current_level_id))
    level = level_result.scalar_one()

    # Prompt (seviyeye özel yönergelerle) + okunabilirlik kontrolü
    prompt = _build_reading_prompt(level, words)
    model_name = "claude-haiku-4-5-20251001"
    content, glossary = _generate_reading(prompt, level.code, model_name, max_tokens=500)
    wc = len(content.split())

    # Kaydet
    passage = ReadingPassage(
        session_id=session_id,
        content=content,
        word_count=wc,
        target_words=[w.id for w in words],
        prompt_used=prompt,
        model_used=model_name,
    )
    db.add(passage)
    await db.commit()
    await db.refresh(passage)

    return passage
