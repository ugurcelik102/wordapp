import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User, UserProfile
from app.models.package import WordPackage
from app.models.session import Session, SessionExercise
from app.models.progress import UserWordProgress
from app.schemas.sessions import (
    SessionCreateRequest, SessionResponse,
    ExerciseSubmitRequest, ExerciseResponse,
    SessionCompleteRequest, SessionSummary,
)
from app.services.srs import update_srs, get_new_status

router = APIRouter()


@router.post("", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    payload: SessionCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Bir kelime paketi için yeni session başlatır."""
    # Paketin kullanıcıya ait olduğunu doğrula
    pkg_result = await db.execute(
        select(WordPackage).where(
            WordPackage.id == payload.package_id,
            WordPackage.user_id == current_user.id,
        )
    )
    package = pkg_result.scalar_one_or_none()
    if not package:
        raise HTTPException(status_code=404, detail="Paket bulunamadı")

    # Zaten aktif bir session var mı? Varsa onu döndür
    existing_result = await db.execute(
        select(Session).where(
            Session.package_id == payload.package_id,
            Session.status == "active",
        )
    )
    existing_session = existing_result.scalar_one_or_none()
    if existing_session:
        return existing_session

    session = Session(user_id=current_user.id, package_id=payload.package_id)
    db.add(session)

    # Paketi active yap
    package.status = "active"
    await db.commit()
    await db.refresh(session)

    return session


@router.post("/{session_id}/exercises", response_model=ExerciseResponse)
async def submit_exercise(
    session_id: uuid.UUID,
    payload: ExerciseSubmitRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Tek bir egzersiz sonucunu kaydeder.
    MCQ veya sentence_fill doğruysa SRS'i günceller.
    """
    # Session doğrula
    sess_result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == current_user.id,
            Session.status == "active",
        )
    )
    session = sess_result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Aktif session bulunamadı")

    # Egzersizi kaydet
    exercise = SessionExercise(
        session_id=session_id,
        word_id=payload.word_id,
        exercise_type=payload.exercise_type,
        is_correct=payload.is_correct,
        selected_answer=payload.selected_answer,
        response_time_ms=payload.response_time_ms,
    )
    db.add(exercise)

    # SRS güncelle (overview hariç, sadece test egzersizleri)
    srs_updated = False
    if payload.exercise_type in ("mcq", "sentence_fill") and payload.is_correct is not None:
        prog_result = await db.execute(
            select(UserWordProgress).where(
                UserWordProgress.user_id == current_user.id,
                UserWordProgress.word_id == payload.word_id,
            )
        )
        progress = prog_result.scalar_one_or_none()

        if progress:
            new_ef, new_interval, new_reps, next_date = update_srs(
                ease_factor=float(progress.ease_factor),
                interval_days=progress.interval_days,
                repetitions=progress.repetitions,
                is_correct=payload.is_correct,
            )
            progress.ease_factor = new_ef
            progress.interval_days = new_interval
            progress.repetitions = new_reps
            progress.next_review_date = next_date
            progress.last_reviewed_at = datetime.now(timezone.utc)
            progress.status = get_new_status(new_reps, new_interval)

            if payload.is_correct:
                progress.correct_count += 1
            else:
                progress.incorrect_count += 1

            srs_updated = True

    await db.commit()
    await db.refresh(exercise)

    return ExerciseResponse(
        id=exercise.id,
        word_id=exercise.word_id,
        exercise_type=exercise.exercise_type,
        is_correct=exercise.is_correct,
        srs_updated=srs_updated,
    )


@router.patch("/{session_id}/complete", response_model=SessionSummary)
async def complete_session(
    session_id: uuid.UUID,
    payload: SessionCompleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Session'ı tamamlar ve özet döner."""
    sess_result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == current_user.id,
        )
    )
    session = sess_result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session bulunamadı")

    # Session'ı kapat
    session.status = "completed"
    session.completed_at = datetime.now(timezone.utc)
    session.duration_sec = payload.duration_sec

    # Paketi tamamlandı olarak işaretle
    pkg_result = await db.execute(select(WordPackage).where(WordPackage.id == session.package_id))
    package = pkg_result.scalar_one_or_none()
    if package:
        package.status = "completed"

    # Streak güncelle
    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == current_user.id)
    )
    profile = profile_result.scalar_one_or_none()
    if profile:
        from datetime import date
        today = date.today()
        if profile.last_active_date == today:
            pass  # bugün zaten aktif
        elif profile.last_active_date and (today - profile.last_active_date).days == 1:
            profile.streak_count += 1
            profile.longest_streak = max(profile.longest_streak, profile.streak_count)
        else:
            profile.streak_count = 1
        profile.last_active_date = today

    # İstatistikleri hesapla — YALNIZCA puanlı egzersizler (is_correct dolu olanlar).
    # 'sentence_fill' ve 'pronunciation' adımları puansızdır (is_correct = NULL);
    # bunlar doğruluğa dahil edilmemeli, aksi halde oran yanlış (düşük) çıkar.
    exercises_result = await db.execute(
        select(SessionExercise).where(
            SessionExercise.session_id == session_id,
            SessionExercise.is_correct.isnot(None),
        )
    )
    exercises = exercises_result.scalars().all()

    total = len(exercises)
    correct = sum(1 for e in exercises if e.is_correct)
    accuracy = correct / total if total > 0 else 0.0

    # SRS'de ilerleme kaydeden kelimeler (repetitions > 0)
    advanced_result = await db.execute(
        select(func.count()).select_from(UserWordProgress).where(
            UserWordProgress.user_id == current_user.id,
            UserWordProgress.repetitions > 0,
            UserWordProgress.status != "new",
        )
    )
    words_advanced = advanced_result.scalar() or 0

    # Toplam öğrenilen kelimeleri güncelle
    if profile:
        profile.total_words_learned = words_advanced

    await db.commit()

    return SessionSummary(
        session_id=session_id,
        total_exercises=total,
        correct_count=correct,
        accuracy=round(accuracy, 2),
        words_advanced=words_advanced,
        duration_sec=payload.duration_sec,
    )
