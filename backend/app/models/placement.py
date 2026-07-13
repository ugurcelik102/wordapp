import uuid
from sqlalchemy import String, Integer, ForeignKey, TIMESTAMP, Numeric, text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from datetime import datetime

from app.models.user import Base


class PlacementTest(Base):
    __tablename__ = "placement_tests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))

    questions: Mapped[list["PlacementTestQuestion"]] = relationship(back_populates="test")


class PlacementTestQuestion(Base):
    __tablename__ = "placement_test_questions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    test_id: Mapped[int] = mapped_column(Integer, ForeignKey("placement_tests.id", ondelete="CASCADE"))
    word_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("words.id"))
    question_type: Mapped[str] = mapped_column(String, nullable=False)  # 'definition_mcq', 'fill_blank', 'synonym'
    target_level_id: Mapped[int] = mapped_column(Integer, ForeignKey("levels.id"))
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)

    test: Mapped["PlacementTest"] = relationship(back_populates="questions")


class UserPlacementResult(Base):
    __tablename__ = "user_placement_results"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    test_id: Mapped[int] = mapped_column(Integer, ForeignKey("placement_tests.id"))
    score: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)
    recommended_level_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("levels.id"), nullable=True)
    final_level_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("levels.id"), nullable=True)
    answers: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    completed_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))
