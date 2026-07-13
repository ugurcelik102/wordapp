from pydantic import BaseModel


class ExamQuestionSchema(BaseModel):
    type: str                 # "vocab" | "grammar"
    question: str
    options: list[str]        # 4 şık
    answer: str               # doğru şıkkın metni (options içinde)
    explanation: str | None = None   # kısa Türkçe açıklama


class ExamResponse(BaseModel):
    count: int
    duration_sec: int
    questions: list[ExamQuestionSchema]
