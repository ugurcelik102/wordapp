"""
Durumsuz yapay zekâ uçlarının şemaları.

Kelime havuzu ve kullanıcı ilerlemesi artık cihazda tutulduğu için, üretim
için gereken hedef kelimeleri ve seviyeyi istemci gönderir.
"""
from pydantic import BaseModel, Field

from app.schemas.exam import ExamQuestionSchema  # noqa: F401  (yanıtta kullanılıyor)


class AIWord(BaseModel):
    """İstemcinin gönderdiği hedef kelime (cihazdaki words.json kaydından)."""

    id: str | None = None
    word: str = Field(min_length=1, max_length=64)
    definition: str = Field(default="", max_length=400)
    definition_tr: str | None = Field(default=None, max_length=400)
    part_of_speech: str | None = Field(default=None, max_length=32)


class ReadingRequest(BaseModel):
    """Konu verilirse konu bazlı, verilmezse hedef kelimelerden parça üretilir."""

    level_code: str = Field(default="B1", max_length=2)
    words: list[AIWord] = Field(default_factory=list, max_length=12)
    topic: str | None = Field(default=None, max_length=200)
    as_dialogue: bool = False


class GlossaryItem(BaseModel):
    word: str
    tr: str


class ReadingResponse(BaseModel):
    # "model_used" pydantic'in korumalı "model_" ön ekiyle çakışıyor; alan adı
    # istemcide kullanıldığı için uyarıyı susturuyoruz.
    model_config = {"protected_namespaces": ()}

    content: str
    word_count: int
    target_word_texts: list[str] = []
    model_used: str | None = None
    glossary: list[GlossaryItem] = []


class ExamRequest(BaseModel):
    level_code: str = Field(default="B1", max_length=2)
    count: int = Field(default=20, ge=5, le=30)


class ExamGenerateResponse(BaseModel):
    count: int
    duration_sec: int
    questions: list[ExamQuestionSchema]


class SentenceUsageRequest(BaseModel):
    words: list[AIWord] = Field(min_length=1, max_length=12)


class ExamplesRequest(BaseModel):
    """Paketteki örnek cümlesi olmayan kelimeler; istemci sonucu cihazda saklar."""

    level_code: str = Field(default="B1", max_length=2)
    words: list[AIWord] = Field(min_length=1, max_length=12)


class WordExampleItem(BaseModel):
    word_id: str | None = None
    word: str
    sentence: str
    translation: str | None = None


class ExamplesResponse(BaseModel):
    examples: list[WordExampleItem]
