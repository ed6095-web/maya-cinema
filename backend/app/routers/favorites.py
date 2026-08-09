"""
MAYA Backend — Favorites Router
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.dependencies.auth import get_current_user
from app.models.favorite import Favorite
from app.models.movie import Movie
from app.models.user import User
from app.schemas.watch import FavoriteResponse

router = APIRouter(prefix="/api/favorites", tags=["Favorites"])


@router.get("", response_model=list[FavoriteResponse])
async def get_favorites(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return current user's favorite movies."""
    result = await db.execute(
        select(Favorite)
        .where(Favorite.user_id == current_user.id)
        .order_by(Favorite.created_at.desc())
    )
    return result.scalars().all()


@router.post("/{movie_id}", response_model=FavoriteResponse, status_code=status.HTTP_201_CREATED)
async def add_favorite(
    movie_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Add a movie to current user's favorites."""
    # Check movie exists
    result = await db.execute(select(Movie).where(Movie.id == movie_id, Movie.is_active == True))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found")

    fav = Favorite(user_id=current_user.id, movie_id=movie_id)
    db.add(fav)
    try:
        await db.flush()
        await db.refresh(fav)
        return fav
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already in favorites")


@router.delete("/{movie_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite(
    movie_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Remove a movie from current user's favorites."""
    result = await db.execute(
        select(Favorite).where(
            Favorite.user_id == current_user.id,
            Favorite.movie_id == movie_id,
        )
    )
    fav = result.scalar_one_or_none()
    if not fav:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Favorite not found")
    await db.delete(fav)
