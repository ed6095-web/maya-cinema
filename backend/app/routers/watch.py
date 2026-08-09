"""
MAYA Backend — Watch History Router
Handles progress tracking, history listing, and Continue Watching.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.dependencies.auth import get_current_user
from app.models.movie import Movie
from app.models.user import User
from app.models.watch_history import WatchHistory
from app.schemas.watch import WatchHistoryResponse, WatchProgressUpdate

router = APIRouter(prefix="/api/history", tags=["Watch History"])

COMPLETION_THRESHOLD = 0.90  # 90% = completed


@router.get("", response_model=list[WatchHistoryResponse])
async def get_history(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return current user's watch history, most recent first."""
    result = await db.execute(
        select(WatchHistory)
        .where(WatchHistory.user_id == current_user.id)
        .order_by(WatchHistory.last_watched_at.desc())
    )
    return result.scalars().all()


@router.post("/{movie_id}/progress", response_model=WatchHistoryResponse)
async def update_progress(
    movie_id: int,
    body: WatchProgressUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upsert watch progress for a movie.
    Called every 10-15 seconds during playback.
    Marks as completed if progress >= 90%.
    """
    # Verify movie exists
    result = await db.execute(select(Movie).where(Movie.id == movie_id, Movie.is_active == True))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found")

    # Calculate completion
    completed = False
    if body.duration_seconds and body.duration_seconds > 0:
        completed = (body.progress_seconds / body.duration_seconds) >= COMPLETION_THRESHOLD

    # Upsert: update if exists, create if not
    result = await db.execute(
        select(WatchHistory).where(
            WatchHistory.user_id == current_user.id,
            WatchHistory.movie_id == movie_id,
        )
    )
    history = result.scalar_one_or_none()

    if history:
        history.progress_seconds = body.progress_seconds
        if body.duration_seconds:
            history.duration_seconds = body.duration_seconds
        history.completed = completed
    else:
        history = WatchHistory(
            user_id=current_user.id,
            movie_id=movie_id,
            progress_seconds=body.progress_seconds,
            duration_seconds=body.duration_seconds,
            completed=completed,
        )
        db.add(history)

    await db.flush()
    await db.refresh(history)
    return history


@router.delete("/{movie_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_from_history(
    movie_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Remove a movie from watch history."""
    result = await db.execute(
        select(WatchHistory).where(
            WatchHistory.user_id == current_user.id,
            WatchHistory.movie_id == movie_id,
        )
    )
    history = result.scalar_one_or_none()
    if not history:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="History entry not found")
    await db.delete(history)
