"""
Durumsuz yapay zekâ uçları — veritabanı ve üyelik gerektirmez.

Kelime havuzu ve ilerleme cihazda tutulur; istemci üretim için gereken
kelimeleri ve seviyeyi gönderir. Bu uçlar kimliksiz olduğu için
`ai_quota` bağımlılığıyla cihaz/IP kotasına tabidir.
"""
from fastapi import APIRouter, Depends, HTTPException

from app.core.config import settings
from app.core.ratelimit import ai_quota
from app.schemas.ai import (
    ExamGenerateResponse, ExamRequest, ReadingRequest, ReadingResponse,
    SentenceUsageRequest,
)
from app.schemas.sentence_usage import SentenceExercisesResponse
from app.services import ai

router = APIRouter(dependencies=[Depends(ai_quota)])


def _require_api_key() -> None:
    if not settings.ANTHROPIC_API_KEY:
        raise HTTPException(status_code=503, detail="ANTHROPIC_API_KEY ayarlanmamış.")


@router.post("/reading", response_model=ReadingResponse)
async def reading(payload: ReadingRequest):
    """Okuma parçası üretir.

    `topic` verilirse konu/senaryo bazlı (isteğe bağlı diyalog), verilmezse
    gönderilen hedef kelimelerden bir parça üretilir.
    """
    _require_api_key()
    if not payload.topic and not payload.words:
        raise HTTPException(
            status_code=400,
            detail="Parça üretmek için ya bir konu ya da en az bir kelime gerekir.",
        )
    try:
        data = await ai.generate_reading(
            level_code=payload.level_code,
            words=payload.words,
            topic=payload.topic,
            as_dialogue=payload.as_dialogue,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Parça üretilemedi: {e}")
    return ReadingResponse(**data)


@router.post("/exam", response_model=ExamGenerateResponse)
async def exam(payload: ExamRequest):
    """Seviyeye uygun çoktan seçmeli deneme sınavı üretir."""
    _require_api_key()
    questions = await ai.generate_exam(payload.level_code, payload.count)
    if not questions:
        raise HTTPException(status_code=502, detail="Sınav üretilemedi. Tekrar deneyin.")
    # Soru başına 45 saniye.
    return ExamGenerateResponse(
        count=len(questions),
        duration_sec=len(questions) * 45,
        questions=questions,
    )


@router.post("/sentence-usage", response_model=SentenceExercisesResponse)
async def sentence_usage(payload: SentenceUsageRequest):
    """Gönderilen kelimeler için cümle kurma/boşluk doldurma alıştırmaları üretir."""
    _require_api_key()
    exercises = await ai.generate_sentence_exercises(payload.words)
    if not exercises:
        raise HTTPException(
            status_code=502, detail="Alıştırma üretilemedi. Tekrar deneyin."
        )
    return SentenceExercisesResponse(count=len(exercises), exercises=exercises)
