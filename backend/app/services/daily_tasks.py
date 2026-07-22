import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_task import DailyTaskCompletion
from app.models.package import WordPackage

# Günlük görevler — öncelik sırası (1 → 3). Sıra bozulmadan çalışılır:
# önceki görev bitmeden sonraki açılmaz.
TASK_ORDER: list[str] = ["review", "new_words", "sentence_usage"]


async def get_completed_keys(db: AsyncSession, user_id: uuid.UUID, day: date | None = None) -> set[str]:
    """Bugün tamamlanmış görev anahtarlarını döner."""
    day = day or date.today()

    result = await db.execute(
        select(DailyTaskCompletion.task_key).where(
            DailyTaskCompletion.user_id == user_id,
            DailyTaskCompletion.task_date == day,
        )
    )
    completed = set(result.scalars().all())

    # "Yeni Kelimeler" ayrıca paket durumundan da türetilir (geriye dönük uyum).
    pkg_status = (
        await db.execute(
            select(WordPackage.status).where(
                WordPackage.user_id == user_id,
                WordPackage.package_date == day,
            )
        )
    ).scalar_one_or_none()
    if pkg_status == "completed":
        completed.add("new_words")

    return completed


async def mark_completed(db: AsyncSession, user_id: uuid.UUID, key: str, day: date | None = None) -> None:
    """Görevi bugün için tamamlandı işaretler (zaten varsa dokunmaz)."""
    if key not in TASK_ORDER:
        raise ValueError(f"Bilinmeyen görev: {key}")
    day = day or date.today()

    exists = (
        await db.execute(
            select(DailyTaskCompletion.id).where(
                DailyTaskCompletion.user_id == user_id,
                DailyTaskCompletion.task_key == key,
                DailyTaskCompletion.task_date == day,
            )
        )
    ).scalar_one_or_none()
    if exists:
        return

    db.add(DailyTaskCompletion(user_id=user_id, task_key=key, task_date=day))
    await db.commit()


def build_status(completed: set[str]) -> list[dict]:
    """Tamamlanma kümesinden sıralı kilit durumunu üretir."""
    items: list[dict] = []
    previous_done = True
    for idx, key in enumerate(TASK_ORDER, start=1):
        is_done = key in completed
        items.append({
            "key": key,
            "order": idx,
            "completed": is_done,
            "unlocked": previous_done and not is_done,
        })
        previous_done = previous_done and is_done
    return items
