from datetime import date
from pydantic import BaseModel


class DailyTaskItem(BaseModel):
    key: str          # review | new_words | sentence_usage
    order: int        # 1 = ilk öncelik
    completed: bool   # bugün tamamlandı mı
    unlocked: bool    # önceki öncelikler bittiği için açık mı


class DailyTasksStatus(BaseModel):
    date: date
    tasks: list[DailyTaskItem]


class DailyTaskCompleteRequest(BaseModel):
    key: str
