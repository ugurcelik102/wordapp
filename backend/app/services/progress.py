"""
İlerleme: kelime testi sonuçları + kelime türüne (part-of-speech) göre gruplama.
"""
import uuid

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc

from app.models.progress import TestResult, UserWordProgress
from app.models.word import Word


async def save_test_result(db: AsyncSession, user_id: uuid.UUID, correct: int, total: int) -> None:
    db.add(TestResult(user_id=user_id, correct=max(0, correct), total=max(0, total)))
    await db.commit()


async def get_progress_summary(db: AsyncSession, user_id: uuid.UUID, recent_limit: int = 10) -> dict:
    recent_res = await db.execute(
        select(TestResult)
        .where(TestResult.user_id == user_id)
        .order_by(desc(TestResult.taken_at))
        .limit(recent_limit)
    )
    recent = list(recent_res.scalars().all())

    agg = await db.execute(
        select(
            func.count(),
            func.coalesce(func.sum(TestResult.correct), 0),
            func.coalesce(func.sum(TestResult.total), 0),
        ).where(TestResult.user_id == user_id)
    )
    count, sum_correct, sum_total = agg.one()
    avg_accuracy = (float(sum_correct) / float(sum_total)) if sum_total else 0.0
    last = recent[0] if recent else None

    return {
        "tests_taken": count,
        "avg_accuracy": round(avg_accuracy, 2),
        "last_correct": last.correct if last else None,
        "last_total": last.total if last else None,
        "recent": [
            {"correct": r.correct, "total": r.total, "taken_at": r.taken_at} for r in recent
        ],
    }


_POS_LABEL = {
    "noun": "İsim",
    "verb": "Fiil",
    "adjective": "Sıfat",
    "adverb": "Zarf",
    "preposition": "Edat",
    "conjunction": "Bağlaç",
    "pronoun": "Zamir",
    "determiner": "Belirteç",
    "article": "Artikel",
    "interjection": "Ünlem",
    "other": "Diğer",
}


async def get_learned_by_category(db: AsyncSession, user_id: uuid.UUID) -> list[dict]:
    learned_filter = (
        UserWordProgress.user_id == user_id,
        UserWordProgress.status.in_(["learning", "review", "mastered"]),
    )

    learned_res = await db.execute(
        select(Word.part_of_speech, func.count())
        .join(UserWordProgress, UserWordProgress.word_id == Word.id)
        .where(*learned_filter)
        .group_by(Word.part_of_speech)
    )
    learned = {(pos or "other"): c for pos, c in learned_res.all()}

    total_res = await db.execute(
        select(Word.part_of_speech, func.count())
        .where(Word.is_active == True)  # noqa: E712
        .group_by(Word.part_of_speech)
    )
    totals = {(pos or "other"): c for pos, c in total_res.all()}

    items: list[dict] = []
    for key in set(list(learned.keys()) + list(totals.keys())):
        items.append({
            "key": key,
            "label": _POS_LABEL.get(key, key.capitalize()),
            "learned": int(learned.get(key, 0)),
            "total": int(totals.get(key, 0)),
        })
    # Öğrenileni en çok olandan aza sırala
    items.sort(key=lambda x: (-x["learned"], -x["total"]))
    return items
