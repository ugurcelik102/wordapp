import uuid
from datetime import date, datetime

from sqlalchemy import String, Date, TIMESTAMP, ForeignKey, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.user import Base


class DailyTaskCompletion(Base):
    """Günlük görevlerin (tekrar / yeni kelimeler / cümle içinde kullanım)
    gün bazlı tamamlanma kaydı. Bir kayıt varsa o görev o gün için bitmiştir."""

    __tablename__ = "daily_task_completions"
    __table_args__ = (
        UniqueConstraint("user_id", "task_key", "task_date", name="uq_daily_task_user_key_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    task_key: Mapped[str] = mapped_column(String, nullable=False)  # review | new_words | sentence_usage
    task_date: Mapped[date] = mapped_column(Date, server_default=text("CURRENT_DATE"))
    completed_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))
