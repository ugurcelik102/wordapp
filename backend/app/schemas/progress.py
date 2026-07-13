from datetime import datetime
from pydantic import BaseModel


class TestResultCreate(BaseModel):
    correct: int
    total: int


class TestResultItem(BaseModel):
    correct: int
    total: int
    taken_at: datetime


class ProgressSummary(BaseModel):
    tests_taken: int
    avg_accuracy: float
    last_correct: int | None = None
    last_total: int | None = None
    recent: list[TestResultItem] = []


class CategoryProgressItem(BaseModel):
    key: str
    label: str
    learned: int
    total: int


class CategoryProgressResponse(BaseModel):
    categories: list[CategoryProgressItem]
