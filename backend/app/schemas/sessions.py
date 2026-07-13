import uuid
from pydantic import BaseModel
from datetime import datetime
from typing import Literal


class SessionCreateRequest(BaseModel):
    package_id: uuid.UUID


class SessionResponse(BaseModel):
    id: uuid.UUID
    package_id: uuid.UUID
    status: str
    started_at: datetime

    model_config = {"from_attributes": True}


class ExerciseSubmitRequest(BaseModel):
    word_id: uuid.UUID
    exercise_type: Literal["overview", "mcq", "sentence_fill", "pronunciation"]
    is_correct: bool | None = None       # overview için None
    selected_answer: str | None = None
    response_time_ms: int | None = None


class ExerciseResponse(BaseModel):
    id: uuid.UUID
    word_id: uuid.UUID
    exercise_type: str
    is_correct: bool | None
    srs_updated: bool = False            # SRS güncellendi mi


class SessionCompleteRequest(BaseModel):
    duration_sec: int | None = None


class SessionSummary(BaseModel):
    session_id: uuid.UUID
    total_exercises: int
    correct_count: int
    accuracy: float                      # 0.0 - 1.0
    words_advanced: int                  # SRS'de ilerleme kaydeden kelime sayısı
    duration_sec: int | None
