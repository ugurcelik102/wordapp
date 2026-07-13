from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.deps import get_current_user
from app.core.config import settings
from app.models.user import User
from app.schemas.exam import ExamResponse, ExamQuestionSchema
from app.services.exam import generate_exam

router = APIRouter()


@router.get("/generate", response_model=ExamResponse)
async def generate(
    count: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Seviyeye uygun süreli deneme sınavı (çoktan seçmeli kelime + gramer) üretir."""
    if not settings.ANTHROPIC_API_KEY:
        raise HTTPException(status_code=503, detail="ANTHROPIC_API_KEY ayarlanmamış.")

    count = max(5, min(30, count))
    try:
        items = await generate_exam(db, current_user.id, count=count)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sınav üretilemedi: {type(e).__name__}: {e}")

    if not items:
        raise HTTPException(status_code=502, detail="Sınav oluşturulamadı, lütfen tekrar deneyin.")

    return ExamResponse(
        count=len(items),
        duration_sec=len(items) * 60,   # soru başına 60 sn
        questions=[ExamQuestionSchema(**it) for it in items],
    )
