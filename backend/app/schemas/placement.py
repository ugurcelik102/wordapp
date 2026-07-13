import uuid
from pydantic import BaseModel
from typing import Literal


# Teste gönderilen soru formatı
class PlacementQuestion(BaseModel):
    question_id: int
    word: str
    question_type: Literal["definition_mcq", "fill_blank", "synonym"]
    question_text: str          # "What does 'abandon' mean?"
    options: list[str]          # 4 şık (doğru + 3 yanlış)
    target_level_code: str      # hangi seviyeyi ölçüyor (A1, B2, vb.)


class PlacementTestResponse(BaseModel):
    test_id: int
    questions: list[PlacementQuestion]


# Kullanıcının gönderdiği cevaplar
class QuestionAnswer(BaseModel):
    question_id: int
    selected_option: str


class PlacementSubmitRequest(BaseModel):
    test_id: int
    answers: list[QuestionAnswer]


# Sonuç
class PlacementResult(BaseModel):
    score: float                    # 0-100
    recommended_level: str          # 'A1', 'B1', vb.
    recommended_level_id: int
    result_id: uuid.UUID
    breakdown: dict[str, int]       # seviyeye göre doğru sayısı: {"A1": 3, "A2": 2, ...}


# Seviye güncelleme
class LevelUpdateRequest(BaseModel):
    result_id: uuid.UUID
    level_id: int                   # kullanıcının seçtiği seviye (1-6)
