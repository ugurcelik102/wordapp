from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.core.deps import get_current_user
from app.core.config import settings
from app.models.user import User
from app.models.word import Word
from app.models.reading import ReadingPassage
from app.schemas.reading import (
    ReadingGenerateRequest, ReadingPassageResponse, ReadingFromLearnedResponse,
    ReadingFromTopicRequest,
)
from app.services.reading import (
    generate_reading_passage, generate_reading_from_learned,
    generate_reading_from_review, generate_reading_from_topic,
)

router = APIRouter()


@router.post("/from-learned", response_model=ReadingFromLearnedResponse)
async def from_learned(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kullanıcının öğrendiği kelimelerden AI okuma parçası üretir (kaydetmez)."""
    if not settings.ANTHROPIC_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="ANTHROPIC_API_KEY ayarlanmamış. .env dosyasına ekleyin.",
        )
    try:
        data = await generate_reading_from_learned(db=db, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Parça üretilemedi: {str(e)}")
    return ReadingFromLearnedResponse(**data)


@router.post("/from-review", response_model=ReadingFromLearnedResponse)
async def from_review(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Tekrar zamanı gelen kelimelerden AI okuma parçası üretir."""
    if not settings.ANTHROPIC_API_KEY:
        raise HTTPException(status_code=503, detail="ANTHROPIC_API_KEY ayarlanmamış.")
    try:
        data = await generate_reading_from_review(db=db, user_id=current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Parça üretilemedi: {str(e)}")
    return ReadingFromLearnedResponse(**data)


@router.post("/from-topic", response_model=ReadingFromLearnedResponse)
async def from_topic(
    payload: ReadingFromTopicRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Belirli bir konu/senaryo hakkında (isteğe bağlı diyalog) okuma parçası üretir."""
    if not settings.ANTHROPIC_API_KEY:
        raise HTTPException(status_code=503, detail="ANTHROPIC_API_KEY ayarlanmamış.")
    topic = payload.topic.strip()
    if not topic:
        raise HTTPException(status_code=400, detail="Konu boş olamaz.")
    try:
        data = await generate_reading_from_topic(
            db=db, user_id=current_user.id, topic=topic, as_dialogue=payload.as_dialogue
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Parça üretilemedi: {str(e)}")
    return ReadingFromLearnedResponse(**data)


@router.post("/generate", response_model=ReadingPassageResponse)
async def generate(
    payload: ReadingGenerateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Session'daki kelimelerle AI okuma parçası üretir.
    Aynı session için tekrar çağrılırsa cache'den döner.
    """
    if not settings.ANTHROPIC_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="ANTHROPIC_API_KEY ayarlanmamış. .env dosyasına ekleyin.",
        )

    try:
        passage = await generate_reading_passage(
            db=db,
            session_id=payload.session_id,
            user_id=current_user.id,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Parça üretilemedi: {str(e)}")

    # Hedef kelimelerin metinlerini getir (vurgulama için).
    texts: list[str] = []
    if passage.target_words:
        words_res = await db.execute(select(Word.word).where(Word.id.in_(passage.target_words)))
        texts = list(words_res.scalars().all())

    return ReadingPassageResponse(
        id=passage.id,
        session_id=passage.session_id,
        content=passage.content,
        word_count=passage.word_count,
        target_words=passage.target_words,
        target_word_texts=texts,
        model_used=passage.model_used,
        created_at=passage.created_at,
    )


@router.get("/{session_id}", response_model=ReadingPassageResponse)
async def get_passage(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Daha önce üretilmiş okuma parçasını getirir."""
    import uuid
    result = await db.execute(
        select(ReadingPassage).where(ReadingPassage.session_id == uuid.UUID(session_id))
    )
    passage = result.scalar_one_or_none()
    if not passage:
        raise HTTPException(status_code=404, detail="Okuma parçası bulunamadı")
    return passage
