import uuid
from sqlalchemy import Integer, ForeignKey, TIMESTAMP, Date, String, text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from datetime import datetime, date

from app.models.user import Base
from app.models.word import Word


class WordPackage(Base):
    __tablename__ = "word_packages"
    __table_args__ = (UniqueConstraint("user_id", "package_date", name="uq_user_package_date"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    level_id: Mapped[int] = mapped_column(Integer, ForeignKey("levels.id"))
    package_date: Mapped[date] = mapped_column(Date, server_default=text("CURRENT_DATE"))
    word_count: Mapped[int] = mapped_column(Integer, default=6)
    status: Mapped[str] = mapped_column(String, default="pending")  # pending, active, completed
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), server_default=text("NOW()"))

    items: Mapped[list["WordPackageItem"]] = relationship(back_populates="package", order_by="WordPackageItem.sort_order", cascade="all, delete-orphan")


class WordPackageItem(Base):
    __tablename__ = "word_package_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    package_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("word_packages.id", ondelete="CASCADE"))
    word_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("words.id"))
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)

    package: Mapped["WordPackage"] = relationship(back_populates="items")
    word: Mapped["Word"] = relationship()
