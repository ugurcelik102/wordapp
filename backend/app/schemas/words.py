import uuid
from pydantic import BaseModel
from datetime import date


class WordExampleSchema(BaseModel):
    sentence: str
    translation: str | None
    is_primary: bool

    model_config = {"from_attributes": True}


class WordDetailSchema(BaseModel):
    id: uuid.UUID
    word: str
    definition: str
    definition_tr: str | None
    ipa: str | None
    audio_url: str | None
    part_of_speech: str | None
    register: str
    examples: list[WordExampleSchema]
    mcq_options: list[str]       # doğru tanım + 3 distractor, karışık
    word_family: list[str]       # ['learning', 'learner', 'learned']

    model_config = {"from_attributes": True}


class PackageWordSchema(BaseModel):
    id: uuid.UUID
    word: str
    definition: str
    definition_tr: str | None
    ipa: str | None
    audio_url: str | None
    part_of_speech: str | None
    primary_example: str | None

    model_config = {"from_attributes": True}


class WordPackageSchema(BaseModel):
    id: uuid.UUID
    package_date: date
    word_count: int
    status: str
    words: list[PackageWordSchema]

    model_config = {"from_attributes": True}


class ReviewWordsResponse(BaseModel):
    count: int
    words: list[PackageWordSchema]


class PackageStatusResponse(BaseModel):
    exists: bool
    completed: bool


class LearnedWordsResponse(BaseModel):
    words: list[PackageWordSchema]
    total: int
    offset: int
    has_more: bool


class ReviewSubmitRequest(BaseModel):
    word_id: uuid.UUID
    is_correct: bool


class ReviewSubmitResponse(BaseModel):
    srs_updated: bool
    next_review_date: date | None = None
