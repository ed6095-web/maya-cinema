"""
MAYA Backend — Movie Pydantic Schemas
"""
from datetime import datetime
from pydantic import BaseModel, Field


class GenreSchema(BaseModel):
    id: int
    name: str
    slug: str
    model_config = {"from_attributes": True}


class MovieBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = None
    release_year: int | None = Field(None, ge=1888, le=2100)
    duration: int | None = Field(None, ge=1)  # seconds
    language: str | None = None
    rating: float | None = Field(None, ge=0.0, le=10.0)
    is_featured: bool = False
    is_active: bool = True


class MovieCreate(MovieBase):
    genre_ids: list[int] = []
    category_ids: list[int] = []


class MovieUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    release_year: int | None = None
    duration: int | None = None
    language: str | None = None
    rating: float | None = None
    is_featured: bool | None = None
    is_active: bool | None = None
    genre_ids: list[int] | None = None
    category_ids: list[int] | None = None


class MovieResponse(MovieBase):
    id: int
    poster_path: str | None
    video_path: str | None
    file_size: int | None
    resolution: str | None
    genres: list[GenreSchema] = []
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


class MovieListResponse(BaseModel):
    items: list[MovieResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
