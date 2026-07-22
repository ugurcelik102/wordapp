from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.daily_tasks import DailyTasksStatus, DailyTaskItem, DailyTaskCompleteRequest
from app.services.daily_tasks import get_completed_keys, mark_completed, build_status

router = APIRouter()


@router.get("/status", response_model=DailyTasksStatus)
async def daily_tasks_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Bugünün görev durumunu döner: hangi görev bitti, hangisi açık.
    Sıra: 1) Kelime Tekrarı 2) Yeni Kelimeler 3) Cümle İçinde Kullanım."""
    completed = await get_completed_keys(db, current_user.id)
    return DailyTasksStatus(
        date=date.today(),
        tasks=[DailyTaskItem(**it) for it in build_status(completed)],
    )


@router.post("/complete", response_model=DailyTasksStatus)
async def complete_daily_task(
    payload: DailyTaskCompleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Bir günlük görevi tamamlandı işaretler ve güncel durumu döner."""
    try:
        await mark_completed(db, current_user.id, payload.key)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    completed = await get_completed_keys(db, current_user.id)
    return DailyTasksStatus(
        date=date.today(),
        tasks=[DailyTaskItem(**it) for it in build_status(completed)],
    )
