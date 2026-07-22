from fastapi import APIRouter
from app.api.v1.endpoints import (
    auth, users, placement, words, sessions, reading, sentence_usage, exam, progress, daily_tasks,
)

api_router = APIRouter()

api_router.include_router(auth.router,           prefix="/auth",           tags=["auth"])
api_router.include_router(users.router,          prefix="/users",          tags=["users"])
api_router.include_router(placement.router,      prefix="/placement",      tags=["placement"])
api_router.include_router(words.router,          prefix="/words",          tags=["words"])
api_router.include_router(sessions.router,       prefix="/sessions",       tags=["sessions"])
api_router.include_router(reading.router,        prefix="/reading",        tags=["reading"])
api_router.include_router(sentence_usage.router, prefix="/sentence-usage", tags=["sentence-usage"])
api_router.include_router(exam.router,           prefix="/exam",           tags=["exam"])
api_router.include_router(progress.router,       prefix="/progress",       tags=["progress"])
api_router.include_router(daily_tasks.router,    prefix="/daily-tasks",    tags=["daily-tasks"])
