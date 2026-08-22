"""
MAYA Backend — External Media ORM Model
"""
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ExternalMedia(Base):
    __tablename__ = "external_media"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )

    # User-facing metadata
    title: Mapped[str] = mapped_column(String(500), nullable=False, default="External Media")
    thumbnail: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    duration: Mapped[int | None] = mapped_column(Integer, nullable=True)  # in seconds

    # Source information
    source_url: Mapped[str] = mapped_column(String(2048), nullable=False)
    provider: Mapped[str | None] = mapped_column(String(100), nullable=True)
    stream_type: Mapped[str | None] = mapped_column(String(50), nullable=True)  # direct | hls | dash | embed
    media_type: Mapped[str | None] = mapped_column(String(100), nullable=True)  # video/mp4 etc.

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    user: Mapped["User | None"] = relationship("User", back_populates="external_media")

    def __repr__(self) -> str:
        return f"<ExternalMedia id={self.id} title={self.title!r} provider={self.provider!r}>"
