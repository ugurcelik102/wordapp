import uuid
from sqlalchemy import Integer, ForeignKey, TIMESTAMP, Date, Numeric, text, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from datetime import datetime, date

from app.models.user import Base
from app.models.word import Word


class UserWordProgress(Base):
    __tablename__ = "user_word_progress"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    word_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("words.id", ondelete="CASCADE"))
    status: Mapped[str] = mapped_column(String, default="new")  # new, learning, review, mastered
    ease_factor: Mapped[float] = mapped_column(Numeric(4, 2), default=2.5)
    interval_days: Mapped[int] = mapped_column(Integer, default=1)
    repetitions: Mapped[int] = mapped_column(Integer, default=0)
    next_review_date: Mapped[date] = mapped_column(Date, server_default=text("CURRENT_DATE"))
    last_reviewed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    correct_count: Mapped[int] = mapped_column(Integer, default=0)
    incorrect_count: Mapped[int] = mapped_column(Integer, default=0)

    word: Mapped["Word"] = relationship()


class TestResult(Base):
    """Kelime testi (öğrenilen kelimeler) sonucu — ilerleme için saklanır."""
    __tablename__ = "test_results"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    correct: Mapped[int] = mapped_column(Integer, default=0)
    total: Mapped[int] = mapped_column(Integer, default=0)
    taken_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))
