import uuid
from sqlalchemy import Integer, ForeignKey, TIMESTAMP, String, Boolean, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from datetime import datetime

from app.models.user import Base
from app.models.word import Word


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    package_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("word_packages.id"))
    status: Mapped[str] = mapped_column(String, default="active")  # active, completed, abandoned
    started_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))
    completed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    duration_sec: Mapped[int | None] = mapped_column(Integer, nullable=True)

    exercises: Mapped[list["SessionExercise"]] = relationship(back_populates="session")


class SessionExercise(Base):
    __tablename__ = "session_exercises"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("sessions.id", ondelete="CASCADE"))
    word_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("words.id"))
    exercise_type: Mapped[str] = mapped_column(String, nullable=False)  # overview, mcq, sentence_fill, pronunciation
    is_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    selected_answer: Mapped[str | None] = mapped_column(String, nullable=True)
    response_time_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    completed_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))

    session: Mapped["Session"] = relationship(back_populates="exercises")
    word: Mapped["Word"] = relationship()
