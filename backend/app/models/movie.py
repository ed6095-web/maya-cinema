"""
MAYA Backend — Movie, Genre, and junction ORM Models
"""
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Table,
    Text,
    Column,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


# Many-to-many: Movie ↔ Genre
movie_genres = Table(
    "movie_genres",
    Base.metadata,
    Column("movie_id", Integer, ForeignKey("movies.id", ondelete="CASCADE"), primary_key=True),
    Column("genre_id", Integer, ForeignKey("genres.id", ondelete="CASCADE"), primary_key=True),
)

# Many-to-many: Movie ↔ Category
movie_categories = Table(
    "movie_categories",
    Base.metadata,
    Column("movie_id", Integer, ForeignKey("movies.id", ondelete="CASCADE"), primary_key=True),
    Column("category_id", Integer, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True),
)


class Genre(Base):
    __tablename__ = "genres"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    slug: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)

    movies: Mapped[list["Movie"]] = relationship("Movie", secondary=movie_genres, back_populates="genres")

    def __repr__(self) -> str:
        return f"<Genre id={self.id} name={self.name!r}>"


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    movies: Mapped[list["Movie"]] = relationship("Movie", secondary=movie_categories, back_populates="categories")

    def __repr__(self) -> str:
        return f"<Category id={self.id} name={self.name!r}>"


class Movie(Base):
    __tablename__ = "movies"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    release_year: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    duration: Mapped[int | None] = mapped_column(Integer, nullable=True)  # seconds
    language: Mapped[str | None] = mapped_column(String(50), nullable=True)
    rating: Mapped[float | None] = mapped_column(Float, nullable=True)
    poster_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    video_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    file_size: Mapped[int | None] = mapped_column(Integer, nullable=True)  # bytes
    resolution: Mapped[str | None] = mapped_column(String(20), nullable=True)  # e.g. "1920x1080"
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    genres: Mapped[list["Genre"]] = relationship("Genre", secondary=movie_genres, back_populates="movies")
    categories: Mapped[list["Category"]] = relationship("Category", secondary=movie_categories, back_populates="movies")
    favorites: Mapped[list["Favorite"]] = relationship("Favorite", back_populates="movie", cascade="all, delete-orphan")
    watch_history: Mapped[list["WatchHistory"]] = relationship("WatchHistory", back_populates="movie", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Movie id={self.id} title={self.title!r} year={self.release_year}>"
