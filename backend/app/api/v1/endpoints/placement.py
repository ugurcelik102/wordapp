import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User, Level
from app.models.word import Word
from app.models.placement import UserPlacementResult
from app.schemas.placement import (
    PlacementTestResponse,
    PlacementSubmitRequest,
    PlacementResult,
    LevelUpdateRequest,
)
from app.services import placement as placement_service

router = APIRouter()


@router.get("/test", response_model=PlacementTestResponse)
async def get_placement_test(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Seviye tespit testini getirir (~20 soru, A1'den C2'ye)."""
    test = await placement_service.get_or_create_default_test(db)
    questions = await placement_service.build_questions(db, test)

    if not questions:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Henüz kelime veritabanı boş. Lütfen önce kelime ekleyin.",
        )

    return PlacementTestResponse(test_id=test.id, questions=questions)


@router.post("/test/submit", response_model=PlacementResult)
async def submit_placement_test(
    payload: PlacementSubmitRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cevapları değerlendirir, seviye önerir ve kaydeder."""
    test = await placement_service.get_or_create_default_test(db)
    questions = await placement_service.build_questions(db, test)

    # Doğru cevap haritası: question_id → word.definition
    # Soruları tekrar oluşturduğumuzda sıra aynı olmalı (seed ile)
    # Basit yaklaşım: question_id = index+1, doğru cevap = word.definition
    correct_map: dict[int, str] = {
        i + 1: q.options[
            next(
                (idx for idx, opt in enumerate(q.options) if opt == q.options[q.options.index(q.options[0])])
            , 0)
        ]
        for i, q in enumerate(questions)
    }

    # Doğru tanımları kelime adından bul (daha güvenilir yaklaşım)
    word_names = [q.word for q in questions]
    words_result = await db.execute(
        select(Word).where(Word.word.in_(word_names))
    )
    words_by_name = {w.word: w.definition for w in words_result.scalars().all()}
    correct_map = {q.question_id: words_by_name.get(q.word, "") for q in questions}

    score, breakdown, recommended_level_id = placement_service.calculate_score(
        questions, payload.answers, correct_map
    )

    result = await placement_service.save_result(
        db=db,
        user_id=current_user.id,
        test_id=test.id,
        score=score,
        recommended_level_id=recommended_level_id,
        answers_payload={str(a.question_id): a.selected_option for a in payload.answers},
    )

    # Önerilen level code'unu bul
    level_result = await db.execute(select(Level).where(Level.id == recommended_level_id))
    level = level_result.scalar_one()

    return PlacementResult(
        score=round(score, 1),
        recommended_level=level.code,
        recommended_level_id=recommended_level_id,
        result_id=result.id,
        breakdown=breakdown,
    )


@router.patch("/level", status_code=status.HTTP_200_OK)
async def update_level(
    payload: LevelUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kullanıcı önerilen seviyeyi değiştirebilir (±1 veya daha fazla)."""
    # Seviye var mı kontrol et
    level_result = await db.execute(select(Level).where(Level.id == payload.level_id))
    level = level_result.scalar_one_or_none()
    if not level:
        raise HTTPException(status_code=404, detail="Geçersiz seviye")

    # Placement result'ı güncelle
    pr_result = await db.execute(
        select(UserPlacementResult).where(
            UserPlacementResult.id == payload.result_id,
            UserPlacementResult.user_id == current_user.id,
        )
    )
    pr = pr_result.scalar_one_or_none()
    if not pr:
        raise HTTPException(status_code=404, detail="Sonuç bulunamadı")

    pr.final_level_id = payload.level_id

    # Profile'ı ayrıca yükle (async SQLAlchemy lazy load desteklemez)
    from app.models.user import UserProfile
    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == current_user.id)
    )
    profile = profile_result.scalar_one_or_none()
    if profile:
        profile.current_level_id = payload.level_id

    await db.commit()

    return {"message": f"Seviye {level.code} olarak güncellendi"}
