"""
MAYA Backend — Genres Router
"""
import re
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.dependencies.auth import get_current_user, require_admin
from app.models.movie import Genre
from app.models.user import User
from app.schemas.movie import GenreSchema
from pydantic import BaseModel


class GenreCreate(BaseModel):
    name: str


router = APIRouter(prefix="/api/genres", tags=["Genres"])


def _slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


@router.get("", response_model=list[GenreSchema])
async def list_genres(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(Genre).order_by(Genre.name))
    return result.scalars().all()


@router.post("", response_model=GenreSchema, status_code=status.HTTP_201_CREATED)
async def create_genre(
    body: GenreCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    slug = _slugify(body.name)
    result = await db.execute(select(Genre).where(Genre.slug == slug))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Genre already exists")
    genre = Genre(name=body.name, slug=slug)
    db.add(genre)
    await db.flush()
    await db.refresh(genre)
    return genre


@router.delete("/{genre_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_genre(
    genre_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    result = await db.execute(select(Genre).where(Genre.id == genre_id))
    genre = result.scalar_one_or_none()
    if not genre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Genre not found")
    await db.delete(genre)
