import uuid
from datetime import date

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_task import DailyTaskCompletion
from app.models.package import WordPackage
from app.models.progress import UserWordProgress

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


async def has_due_reviews(db: AsyncSession, user_id: uuid.UUID, day: date | None = None) -> bool:
    """Bugün tekrarı gelen (SRS) kelime var mı?

    İlk gün gibi tekrar havuzunun boş olduğu durumlarda "Kelime Tekrarı" görevi
    hiç gösterilmez; akış doğrudan "Yeni Kelimeler" ile başlar.
    """
    day = day or date.today()
    count = (
        await db.execute(
            select(func.count())
            .select_from(UserWordProgress)
            .where(
                UserWordProgress.user_id == user_id,
                UserWordProgress.next_review_date <= day,
                UserWordProgress.status.in_(["learning", "review", "mastered"]),
            )
        )
    ).scalar_one()
    return bool(count)


async def active_task_order(
    db: AsyncSession,
    user_id: uuid.UUID,
    completed: set[str],
    day: date | None = None,
) -> list[str]:
    """Bugün için geçerli görev sırasını üretir.

    Tekrar edilecek kelime yoksa ve görev bugün henüz tamamlanmadıysa
    "review" listeden düşer; böylece "Yeni Kelimeler" ilk görev olur.
    Görev bugün tamamlandıysa (gri "tamamlandı" olarak görünmesi için) listede kalır.
    """
    if "review" in completed:
        return list(TASK_ORDER)
    if await has_due_reviews(db, user_id, day):
        return list(TASK_ORDER)
    return [key for key in TASK_ORDER if key != "review"]


def build_status(completed: set[str], order: list[str] | None = None) -> list[dict]:
    """Tamamlanma kümesinden sıralı kilit durumunu üretir.

    `order` verilmezse tüm görevler (varsayılan sıra) kullanılır.
    Listede olmayan görev, istemcide hiç gösterilmez.
    """
    keys = order if order is not None else TASK_ORDER
    items: list[dict] = []
    previous_done = True
    for idx, key in enumerate(keys, start=1):
        is_done = key in completed
        items.append({
            "key": key,
            "order": idx,
            "completed": is_done,
            "unlocked": previous_done and not is_done,
        })
        previous_done = previous_done and is_done
    return items
