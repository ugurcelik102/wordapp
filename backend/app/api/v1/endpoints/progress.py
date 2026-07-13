from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.progress import (
    TestResultCreate, ProgressSummary, TestResultItem,
    CategoryProgressResponse, CategoryProgressItem,
)
from app.services.progress import (
    save_test_result, get_progress_summary, get_learned_by_category,
)

router = APIRouter()


@router.post("/test-result", response_model=ProgressSummary)
async def create_test_result(
    payload: TestResultCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kelime testi sonucunu kaydeder ve güncel özeti döner."""
    if payload.total > 0:
        await save_test_result(db, current_user.id, payload.correct, payload.total)
    data = await get_progress_summary(db, current_user.id)
    return _to_summary(data)


@router.get("/summary", response_model=ProgressSummary)
async def summary(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = await get_progress_summary(db, current_user.id)
    return _to_summary(data)


@router.get("/by-category", response_model=CategoryProgressResponse)
async def by_category(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Öğrenilen kelimeleri türüne (part-of-speech) göre gruplar."""
    items = await get_learned_by_category(db, current_user.id)
    return CategoryProgressResponse(
        categories=[CategoryProgressItem(**it) for it in items]
    )


def _to_summary(data: dict) -> ProgressSummary:
    return ProgressSummary(
        tests_taken=data["tests_taken"],
        avg_accuracy=data["avg_accuracy"],
        last_correct=data["last_correct"],
        last_total=data["last_total"],
        recent=[TestResultItem(**r) for r in data["recent"]],
    )
