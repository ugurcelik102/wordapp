from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.sentence_usage import SentenceExercisesResponse, SentenceExerciseSchema
from app.services.sentence_usage import generate_sentence_exercises

router = APIRouter()


@router.get("/exercises", response_model=SentenceExercisesResponse)
async def sentence_exercises(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Öğrenilen/tekrarı gelen kelimelerden karışık cümle alıştırmaları üretir."""
    try:
        items = await generate_sentence_exercises(db, current_user.id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Alıştırma üretilemedi: {type(e).__name__}: {e}")
    return SentenceExercisesResponse(
        count=len(items),
        exercises=[SentenceExerciseSchema(**it) for it in items],
    )
