import uuid
from sqlalchemy import String, Integer, Boolean, ForeignKey, TIMESTAMP, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from datetime import datetime

from app.models.user import Base


class Word(Base):
    __tablename__ = "words"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    word: Mapped[str] = mapped_column(String, nullable=False)
    definition: Mapped[str] = mapped_column(Text, nullable=False)
    definition_tr: Mapped[str | None] = mapped_column(Text, nullable=True)
    ipa: Mapped[str | None] = mapped_column(String, nullable=True)
    audio_url: Mapped[str | None] = mapped_column(String, nullable=True)
    part_of_speech: Mapped[str | None] = mapped_column(String, nullable=True)
    register: Mapped[str] = mapped_column(String, default="neutral")
    frequency_rank: Mapped[int | None] = mapped_column(Integer, nullable=True)
    level_id: Mapped[int] = mapped_column(Integer, ForeignKey("levels.id"), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))

    examples: Mapped[list["WordExample"]] = relationship(back_populates="word")
    mcq_distractors: Mapped[list["WordMcqDistractor"]] = relationship(back_populates="word")


class WordExample(Base):
    __tablename__ = "word_examples"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    word_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("words.id", ondelete="CASCADE"))
    sentence: Mapped[str] = mapped_column(Text, nullable=False)
    translation: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)

    word: Mapped["Word"] = relationship(back_populates="examples")


class WordMcqDistractor(Base):
    __tablename__ = "word_mcq_distractors"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    word_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("words.id", ondelete="CASCADE"))
    distractor: Mapped[str] = mapped_column(Text, nullable=False)

    word: Mapped["Word"] = relationship(back_populates="mcq_distractors")
