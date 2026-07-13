import uuid
from sqlalchemy import Integer, ForeignKey, TIMESTAMP, Text, String, text
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.models.user import Base


class ReadingPassage(Base):
    __tablename__ = "reading_passages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sessions.id", ondelete="CASCADE"), unique=True
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    word_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    target_words: Mapped[list[uuid.UUID] | None] = mapped_column(ARRAY(UUID(as_uuid=True)), nullable=True)
    prompt_used: Mapped[str | None] = mapped_column(Text, nullable=True)
    model_used: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))
