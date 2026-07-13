import uuid
import random
from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.package import WordPackage, WordPackageItem
from app.schemas.words import (
    WordPackageSchema, PackageWordSchema, WordDetailSchema, WordExampleSchema,
    ReviewWordsResponse, ReviewSubmitRequest, ReviewSubmitResponse,
    PackageStatusResponse, LearnedWordsResponse,
)
from app.services.words import (
    get_or_create_today_package, create_new_package, get_word_detail,
    get_review_words, submit_review, ensure_word_example, get_learned_words,
)

router = APIRouter()


@router.get("/package/today", response_model=WordPackageSchema)
async def today_package(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Bugünkü kelime paketini getirir (yoksa oluşturur)."""
    package = await get_or_create_today_package(db, current_user.id)

    words = []
    for item in package.items:
        w = item.word
        primary = next((e.sentence for e in w.examples if e.is_primary), None)
        words.append(PackageWordSchema(
            id=w.id,
            word=w.word,
            definition=w.definition,
            definition_tr=w.definition_tr,
            ipa=w.ipa,
            audio_url=w.audio_url,
            part_of_speech=w.part_of_speech,
            primary_example=primary,
        ))

    return WordPackageSchema(
        id=package.id,
        package_date=package.package_date,
        word_count=package.word_count,
        status=package.status,
        words=words,
    )


@router.post("/package/new", response_model=WordPackageSchema)
async def new_package(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Yeni paket oluşturur. Bugünkü varsa siler, profildeki daily_word_count kullanılır."""
    try:
        package = await create_new_package(db, current_user.id)
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Yeni paket üretilemedi: {type(e).__name__}: {str(e)}")

    words = []
    for item in package.items:
        w = item.word
        primary = next((e.sentence for e in w.examples if e.is_primary), None)
        words.append(PackageWordSchema(
            id=w.id,
            word=w.word,
            definition=w.definition,
            definition_tr=w.definition_tr,
            ipa=w.ipa,
            audio_url=w.audio_url,
            part_of_speech=w.part_of_speech,
            primary_example=primary,
        ))

    return WordPackageSchema(
        id=package.id,
        package_date=package.package_date,
        word_count=package.word_count,
        status=package.status,
        words=words,
    )


@router.get("/package/status", response_model=PackageStatusResponse)
async def today_package_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Bugünkü paketin durumunu döner (paket OLUŞTURMADAN). completed ise
    'Yeni Kelimeler' butonu istemcide pasifleştirilir."""
    today = date.today()
    result = await db.execute(
        select(WordPackage.status).where(
            WordPackage.user_id == current_user.id,
            WordPackage.package_date == today,
        )
    )
    status_val = result.scalar_one_or_none()
    return PackageStatusResponse(
        exists=status_val is not None,
        completed=(status_val == "completed"),
    )


@router.get("/learned", response_model=LearnedWordsResponse)
async def learned_words(
    offset: int = 0,
    limit: int = 8,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Öğrenilmiş tüm kelimeleri 8'li (sayfalı) döner — kelime testi için."""
    offset = max(0, offset)
    limit = max(1, min(20, limit))
    words_models, total = await get_learned_words(db, current_user.id, offset=offset, limit=limit)

    words = []
    for w in words_models:
        primary = next((e.sentence for e in w.examples if e.is_primary), None)
        words.append(PackageWordSchema(
            id=w.id,
            word=w.word,
            definition=w.definition,
            definition_tr=w.definition_tr,
            ipa=w.ipa,
            audio_url=w.audio_url,
            part_of_speech=w.part_of_speech,
            primary_example=primary,
        ))

    return LearnedWordsResponse(
        words=words,
        total=total,
        offset=offset,
        has_more=(offset + len(words) < total),
    )


@router.get("/review/words", response_model=ReviewWordsResponse)
async def review_words(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """SRS'e göre bugün tekrarı gelen kelimeleri döner."""
    try:
        words_models = await get_review_words(db, current_user.id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Tekrar getirilemedi: {type(e).__name__}: {str(e)}")
    words = []
    for w in words_models:
        primary = next((e.sentence for e in w.examples if e.is_primary), None)
        words.append(PackageWordSchema(
            id=w.id,
            word=w.word,
            definition=w.definition,
            definition_tr=w.definition_tr,
            ipa=w.ipa,
            audio_url=w.audio_url,
            part_of_speech=w.part_of_speech,
            primary_example=primary,
        ))
    return ReviewWordsResponse(count=len(words), words=words)


@router.post("/review/submit", response_model=ReviewSubmitResponse)
async def review_submit(
    payload: ReviewSubmitRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Tek bir tekrar sonucunu SRS'e işler."""
    next_date = await submit_review(db, current_user.id, payload.word_id, payload.is_correct)
    return ReviewSubmitResponse(srs_updated=next_date is not None, next_review_date=next_date)


@router.get("/{word_id}", response_model=WordDetailSchema)
async def word_detail(
    word_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Tek kelime detayını getirir: tanım, örnekler, MCQ seçenekleri."""
    word = await get_word_detail(db, word_id)
    if not word:
        raise HTTPException(status_code=404, detail="Kelime bulunamadı")

    # Örnek cümlesi yoksa üret ve kaydet (bir kez), böylece "Cümle İçinde Kullanım" dolu gelir
    word = await ensure_word_example(db, word)

    distractors = [d.distractor for d in word.mcq_distractors][:3]
    mcq_options = distractors + [word.definition]
    random.shuffle(mcq_options)

    return WordDetailSchema(
        id=word.id,
        word=word.word,
        definition=word.definition,
        definition_tr=word.definition_tr,
        ipa=word.ipa,
        audio_url=word.audio_url,
        part_of_speech=word.part_of_speech,
        register=word.register,
        examples=[WordExampleSchema.model_validate(e) for e in word.examples],
        mcq_options=mcq_options,
        word_family=[],  # ileriki aşamada doldurulacak
    )
