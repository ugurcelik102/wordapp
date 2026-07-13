import uuid
from pydantic import BaseModel
from datetime import datetime


class ReadingGenerateRequest(BaseModel):
    session_id: uuid.UUID


class ReadingFromTopicRequest(BaseModel):
    topic: str
    as_dialogue: bool = True


class GlossaryItem(BaseModel):
    word: str
    tr: str


class ReadingFromLearnedResponse(BaseModel):
    content: str
    word_count: int | None = None
    target_words: list[uuid.UUID] | None = None
    target_word_texts: list[str] = []
    model_used: str | None = None
    glossary: list[GlossaryItem] = []


class ReadingPassageResponse(BaseModel):
    id: uuid.UUID
    session_id: uuid.UUID
    content: str
    word_count: int | None
    target_words: list[uuid.UUID] | None
    target_word_texts: list[str] = []
    model_used: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
